package main

import (
	"context"
	"fmt"
	"math/rand"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/spf13/viper"
)

// type Coord struct {
// 	Long float64
// 	Lat  float64
// }

func getStart(conn *pgxpool.Conn) (Query, error) {

	query := Query{}

	// This is because we will only start from buildings.
	sql := fmt.Sprintf("SELECT dest_id FROM %s.destinations WHERE point_id = 0 ORDER BY random() LIMIT 1;", SCHEMA)

	err := conn.QueryRow(context.Background(), sql).Scan(&query.Startid)
	if err != nil {
		return query, fmt.Errorf("QueryRow failed: %v", err)

	}
	// fmt.Println("StartID generated", query.Startid)
	return query, nil
}

func getDest(conn *pgxpool.Conn, query Query) (Query, error) {

	decider := rand.Float64()
	// fmt.Println(decider)
	var chooser string

	// Hier ist poly_id = 0 -> es war ein punkt -> es kommt aus 'points_to_go'
	if decider <= viper.GetFloat64("ShopHouseRate") {
		chooser = "poly_id"
		// Hier ist point_id = 0 -> es ist ein polygon -> es war ein gebäude
	} else {
		chooser = "point_id"
	}

	sql := fmt.Sprintf(`WITH start AS (
		SELECT * FROM %s.destinations WHERE dest_id = %v
		)
	SELECT 
		start.dest_id::integer as start_id,
		ST_X(ST_Transform(start.way, 4326)) as start_X,
		ST_Y(ST_Transform(start.way, 4326)) as start_Y,

		dest.dest_id, 
		ST_X(ST_Transform(dest.way, 4326)) as dest_X,
		ST_Y(ST_Transform(dest.way, 4326)) as dest_Y,

		ST_Distance(ST_Transform(ST_FORCE2D(start.way), 4647), 
					ST_Transform(ST_FORCE2D(dest.way), 4647))
	FROM %s.destinations dest, start start
		WHERE dest.%v = 0
		ORDER BY random()
		LIMIT 1;
	`, SCHEMA, query.Startid, SCHEMA, chooser)

	err := conn.QueryRow(context.Background(), sql).Scan(
		&query.Startid,
		&query.StartLong,
		&query.StartLat,
		&query.Destid,
		&query.DestLong,
		&query.DestLat,
		&query.Distance)
	if err != nil {
		return query, fmt.Errorf("QueryRow failed: %v", err)

	}
	// fmt.Println("Query generated", query)
	return query, nil
}

func validateQuery(conn *pgxpool.Conn) (Query, error) {
	query, err := getStart(conn)
	if err != nil {
		return query, err
	}

	for i := 0; i < 10; i++ {
		query, err = getDest(conn, query)
		if err != nil {
			return query, err
		}

		if query.Distance > viper.GetFloat64("MinLength") && query.Distance < viper.GetFloat64("MaxLength") {
			// fmt.Println(query)
			return query, nil
		} // } else {
		// 	// fmt.Println(query.Distance, "Was to long")
		// }
	}
	return Query{}, fmt.Errorf("unable to generate valid Query, StartID: %v", query.Startid)
}
