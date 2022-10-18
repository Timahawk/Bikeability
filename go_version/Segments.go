package main

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

func generateSegments(conn *pgxpool.Conn, route *Route) (*Route, error) {
	sql := fmt.Sprintf("SELECT route_id FROM %v.routes WHERE start = %v and dest = %v", SCHEMA, route.Startid, route.Destid)

	var route_id int
	err := conn.QueryRow(context.Background(), sql).Scan(&route_id)
	if err != nil {
		return route, fmt.Errorf("queryRow failed: %v", err)
	}
	route.RouteID = route_id

	tgx, err := conn.Begin(context.Background())
	if err != nil {
		return route, fmt.Errorf("begin transaction failed: %v", err)

	}

	sql = fmt.Sprintf(`
		INSERT INTO %s.route_segments (start, dest, route_id, road_id, seg_id, line_id, geom, len)
		SELECT %v as start, %v as dest, %v as route_id, * 
		FROM (
			SELECT road_id, seg_id, line_id, geom, len
			FROM %s.roadsegs 
			WHERE 
			ST_WITHIN(geom, 
				(SELECT ST_Buffer(ST_FORCE2D(geom), 1) from %s.routes 
					WHERE route_id = %v)
				)
			and road_type != 'railway'
		) X	
		`, SCHEMA, route.Startid, route.Destid, route_id, SCHEMA, SCHEMA, route_id)

	_, err = conn.Exec(context.Background(), sql)
	if err != nil {
		tgx.Rollback(context.Background())
		return route, fmt.Errorf("exec failed: %v", err)
	}
	err = tgx.Commit(context.Background())
	if err != nil {
		tgx.Rollback(context.Background())
		return route, fmt.Errorf("commit transaction failed: %v", err)
	}
	return route, nil
}
