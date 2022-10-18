package main

import (
	"context"
	"encoding/csv"
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/jackc/pgx/v5"
)

type res struct {
	name                                         string
	routes                                       int64
	perm, surface, maxs, infra, p_rail, p_bus    float64
	staight, t_car, len_sh, ffw, b_park, b_rent  float64
	d_water, seg_st, treecnt, park, parking, lit float64
	f_score                                      float64
}

func readCsvFile(filePath string) [][]string {
	f, err := os.Open(filePath)
	if err != nil {
		log.Fatal("Unable to read input file "+filePath, err)
	}
	defer f.Close()

	csvReader := csv.NewReader(f)
	records, err := csvReader.ReadAll()
	if err != nil {
		log.Fatal("Unable to parse file as CSV for "+filePath, err)
	}

	res := [][]string{}
	for _, line := range records {
		split := strings.Split(line[0], ";")
		res = append(res, split)
	}

	return res
}

func getResults(conn *pgx.Conn, schema string) string {
	sql := fmt.Sprintf("SELECT * FROM %s.bikeabiltiy", schema)

	var r res
	err := conn.QueryRow(context.Background(), sql).Scan(&r.name, &r.routes, &r.perm, &r.surface, &r.maxs, &r.infra, &r.p_rail, &r.p_bus, &r.staight, &r.t_car, &r.len_sh, &r.ffw, &r.b_park, &r.b_rent, &r.d_water, &r.seg_st, &r.treecnt, &r.park, &r.parking, &r.lit, &r.f_score)
	if err != nil {
		log.Fatal(err)
	}
	str := fmt.Sprintf("%v", r)
	fmt.Println(str)
	return str
}

func getAllCityValues(conn *pgx.Conn) {
	lines := readCsvFile("../stadtliste.csv")

	fmt.Println("Verify:", lines[0][5])

	f, err := os.Create("data.txt")
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()

	for i, line := range lines {
		if i == 1 {
			continue
		}
		if len(line) == 7 {
			if line[6] == "ja" {
				fmt.Println(line[1], line[6])
				str := getResults(conn, line[1])

				_, err = f.WriteString(str + "\n")
				if err != nil {
					log.Fatal(err)
				}
			}
		}
	}
}

func main() {
	if len(os.Args) == 1 {
		log.Fatal("No Command line Parameter provided!")
	}

	conn, err := pgx.Connect(context.Background(), "postgres://postgres:postgres@postgis:5432/postgres")
	if err != nil {
		log.Fatal(err)
	}

	if os.Args[1] == "all" {
		log.Println("Processing all Cities in Cityfile labeleld 'yes'.")
		getAllCityValues(conn)
	} else {
		log.Println("Processing single city mode", os.Args[1])

		str := getResults(conn, os.Args[1])
		log.Println("Result: ", str)

		f, err := os.OpenFile("results.csv", os.O_CREATE|os.O_WRONLY|os.O_APPEND, os.ModePerm)
		if err != nil {
			log.Fatal(err)
		}
		defer f.Close()

		_, err = f.WriteString(str + "\n")
		if err != nil {
			log.Fatal(err)
		}
	}
}
