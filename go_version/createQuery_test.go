package main

import (
	"context"
	"fmt"
	"os"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
)

var query Query

func BenchmarkValidateQuery(b *testing.B) {
	pool, err := pgxpool.New(context.Background(),
		"postgres://postgres:postgres@localhost:5436/postgres")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Unable to connect to database: %v\n", err)
		os.Exit(1)
	}
	defer pool.Close()

	var query2 Query

	b.ResetTimer()

	for n := 0; n < b.N; n++ {
		conn, _ := pool.Acquire(context.Background())
		defer conn.Release()
		query, err = validateQuery(conn)
		if err != nil {
			if err != nil {
				fmt.Println(err)
				b.Fail()
			}
		}
	}

	query = query2
}
