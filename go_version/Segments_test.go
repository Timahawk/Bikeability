package main

import (
	"context"
	"fmt"
	"os"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
)

var resulterr error

func BenchmarkSegments(b *testing.B) {
	pool, err := pgxpool.New(context.Background(),
		"postgres://postgres:postgres@localhost:5436/postgres")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Unable to connect to database: %v\n", err)
		os.Exit(1)
	}
	defer pool.Close()

	var route Route

	b.ResetTimer()
	for n := 0; n < b.N; n++ {
		conn, _ := pool.Acquire(context.Background())
		defer conn.Release()
		// This is nessary so that the same query will not be cached or sth....
		b.StopTimer()
		query, err := validateQuery(conn)
		if err != nil {
			fmt.Println(err)
			b.Fail()
		}

		route, err = generateRoute(conn, query)
		if err != nil {
			fmt.Println(err)
			b.Fail()
		}
		b.StartTimer()
		_, err = generateSegments(conn, &route)
		if err != nil {
			fmt.Println(err)
			b.Fail()
		}
	}

	resulterr = err
}
