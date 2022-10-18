package main

import (
	"context"
	"fmt"
	"log"
	"math/rand"
	"os"
	"sync"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/spf13/viper"
)

type Query struct {
	Startid   int64
	StartLong float64
	StartLat  float64

	Destid   int64
	DestLong float64
	DestLat  float64

	Distance float64
}

var SCHEMA string

func main() {

	rand.Seed(time.Now().UTC().UnixNano())

	viper.SetConfigName("config")               // name of config file (without extension)
	viper.SetConfigType("env")                  // REQUIRED if the config file does not have the extension in the name
	viper.AddConfigPath("../")                  // path to look for the config file in
	viper.AddConfigPath("$HOME/brouter_caller") // call multiple times to add many search paths
	viper.AddConfigPath(".")                    // optionally look for config in the working directory
	err := viper.ReadInConfig()                 // Find and read the config file
	if err != nil {                             // Handle errors reading the config file
		panic(fmt.Errorf("fatal error config file: %w", err))
	}

	pool, err := pgxpool.New(context.Background(), viper.GetString("PSQLstring"))
	if err != nil {
		log.Printf("Unable to connect to database: %v\n", err)
		os.Exit(1)
	}
	defer pool.Close()
	log.Println("Successfully connected to db!")

	// log.Println(viper.GetString("TESTSTRING"), "successfully transmitted.")

	if len(os.Args) == 1 {
		SCHEMA = viper.GetString("Schema")
		log.Println("Using Schema from config.env")
	} else {
		log.Println("Using Schema System Variable/ Args Parameter.")
		SCHEMA = os.Args[1]
	}
	start := time.Now()

	// To secure all goroutines finish.
	wg := sync.WaitGroup{}
	wg.Add(viper.GetInt("Routes"))

	for i := 0; i < viper.GetInt("Routes"); i++ {

		// Simply wrapped into this anonymous function, so that they all run in parallel.
		go func() {
			defer wg.Done()
			conn, err := pool.Acquire(context.Background())
			if err != nil {
				log.Println(err)
				return
			}
			defer conn.Release()

			query, err := validateQuery(conn)
			if err != nil {
				log.Println(err)
				return
			}

			route, err := generateRoute(conn, query)
			if err != nil {
				log.Println(err)
				return
			}

			_, err = generateSegments(conn, &route)
			if err != nil {
				log.Println(err)
				return
			}
		}()
	}

	// This blocks until all goroutines finish.
	wg.Wait()

	elapsed := time.Since(start)
	log.Printf("Generation of %v in %s", viper.Get("Routes"), elapsed)
}
