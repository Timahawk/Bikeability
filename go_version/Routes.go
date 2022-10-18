package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/paulmach/orb/geojson"
	"github.com/spf13/viper"
)

func callBrouter(query Query, result *geojson.FeatureCollection, port int64, profile string) error {

	link := fmt.Sprintf("http://%s:%d/brouter?lonlats=%v,%v|%v,%v&profile=%v&alternativeidx=0&format=geojson",
		viper.GetString("BrouterLink"),
		port,
		query.StartLong,
		query.StartLat,
		query.DestLong,
		query.DestLat,
		profile)

	resp, err := http.Get(link)
	if err != nil {
		return fmt.Errorf("get brouter failed: %v", err)
	}

	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("brouter response read failed: %v", err)
	}

	if resp.StatusCode != 200 {
		// fmt.Printf("The status code was not 200, but %v - %s", resp.StatusCode, body)
		return fmt.Errorf("statusCode %v, %s, StartID %v, DestID %v", resp.StatusCode, body, query.Startid, query.Destid)
	}

	if err := json.Unmarshal([]byte(body), &result); err != nil {
		return fmt.Errorf("marshalling failed: %v", err)
	}
	return nil
}

type Route struct {
	Startid   int64
	StartLong float64
	StartLat  float64

	Destid   int64
	DestLong float64
	DestLat  float64

	Distance        float64
	Tracklength     interface{}
	Filtered_ascent interface{}
	Plain_ascent    interface{}
	Total_time      interface{}
	Total_energy    interface{}
	Cost            interface{}
	// Geom              string
	Tracklength_short interface{}
	Total_time_car    interface{}

	RouteID int
}

func generateRoute(conn *pgxpool.Conn, query Query) (Route, error) {

	var trekking, shortest, car geojson.FeatureCollection

	err := callBrouter(query, &trekking, 80, "trekking")
	if err != nil {
		return Route{}, fmt.Errorf("trekking error: %w", err)
	}
	err = callBrouter(query, &shortest, 80, "shortest")
	if err != nil {
		return Route{}, fmt.Errorf("shortest error: %w", err)
	}
	err = callBrouter(query, &car, 80, "car-vario")
	if err != nil {
		return Route{}, fmt.Errorf("car error: %w", err)
	}

	route := Route{
		query.Startid,
		query.StartLong,
		query.StartLat,
		query.Destid,
		query.DestLong,
		query.DestLat,
		query.Distance,
		trekking.Features[0].Properties["track-length"],
		trekking.Features[0].Properties["filtered ascend"],
		trekking.Features[0].Properties["plain-ascend"],
		trekking.Features[0].Properties["total-time"],
		trekking.Features[0].Properties["total-energy"],
		trekking.Features[0].Properties["cost"],
		// trekking.Properties[""],
		shortest.Features[0].Properties["track-length"],
		car.Features[0].Properties["total-time"],
		0}

	feature := trekking.Features[0]

	geojson, _ := feature.MarshalJSON()

	type Geom struct {
		Geometry struct {
			Coordinates interface{}
			Type        interface{}
		}
	}

	var geom Geom

	err = json.Unmarshal(geojson, &geom)
	if err != nil {
		return Route{}, fmt.Errorf("unmarshalling of geojson failed: %v", err)
	}
	geojson_coords, err := json.Marshal(geom.Geometry.Coordinates)
	if err != nil {
		return Route{}, fmt.Errorf("marshalling into geojson_coords failed: %v", err)
	}
	geojson_typ, err := json.Marshal(geom.Geometry.Type)
	if err != nil {
		return Route{}, fmt.Errorf("marshalling into geojson_type failed: %v", err)
	}

	// fmt.Println(string(geojson_coords) + string(geojson_typ))
	geojson_geom := `{"coordinates":` + string(geojson_coords) + `,"type":` + string(geojson_typ) + "}"

	sql := fmt.Sprintf(`
	INSERT INTO %s.routes (start, startlat, startlon, dest, destlat, destlon, length,
		straightline_length, track_length, filtered_ascend, plain_ascend,
		total_time, total_energy, cost, geom, fastest_track_length, car_total_time)
		VALUES (%v,
				%v,
				%v,
				%v,
				%v,
				%v,
				ST_Length(ST_Transform(ST_SetSRID(ST_GeomFromGeoJSON('%s'), 4326), 4647)), 
				%v,
				%v,
				%v,
				%v,
				%v,
				%v,
				%v,
				ST_Transform(ST_SetSRID(ST_GeomFromGeoJSON('%s'), 4326), 3857),
				%v,
				%v
	);
	`, SCHEMA,
		route.Startid, route.StartLong, route.StartLat, route.Destid,
		route.DestLong, route.DestLat, geojson_geom, route.Distance,
		route.Tracklength, route.Filtered_ascent, route.Plain_ascent,
		route.Total_time, route.Total_energy, route.Cost, geojson_geom,
		route.Tracklength_short, route.Total_time_car)

	// fmt.Println(sql)

	tgx, err := conn.Begin(context.Background())
	if err != nil {
		return Route{}, fmt.Errorf("begin transaction failed: %v", err)

	}
	_, err = conn.Exec(context.Background(), sql)
	if err != nil {
		tgx.Rollback(context.Background())
		return Route{}, fmt.Errorf("exec failed: %v", err)

	}
	err = tgx.Commit(context.Background())
	if err != nil {
		tgx.Rollback(context.Background())
		return Route{}, fmt.Errorf("commit transaction failed: %v", err)

	}
	return route, nil
}
