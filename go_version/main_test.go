package main

import (
	"fmt"
	"math/rand"
	"testing"
	"time"

	"github.com/paulmach/orb/geojson"
	"github.com/spf13/viper"
)

// go test -bench=Benchmark_callBrouter -benchtime=10s
//
// goos: windows
// goarch: amd64
// pkg: github.com/Timahawk/RouteGenerator
// cpu: AMD Ryzen 5 3600X 6-Core Processor
// Benchmark_callBrouter-12              96         132173976 ns/op
// PASS
// ok      github.com/Timahawk/RouteGenerator      12.859s
func Benchmark_callBrouter(b *testing.B) {
	var err error
	viper.Set("BrouterLink", "127.0.0.1")
	rand.Seed(time.Now().UnixNano())

	// If you try to fit this into a goroutine, everything breaks!
	for n := 0; n < b.N; n++ {

		s_x := float64(rand.Intn(2000)) / 10000
		s_y := float64(rand.Intn(2500)) / 10000

		o_x := float64(rand.Intn(2000)) / 10000
		o_y := float64(rand.Intn(2500)) / 10000

		query := Query{
			0,
			s_x + 10.8,  // random Longitude around Augsburg
			s_y + 48.30, //random Latitude around Augsburg

			0,
			o_x + 10.8,  // random Longitude around Augsburg
			o_y + 48.30, //random Latitude around Augsburg
			0}
		var geojson *geojson.FeatureCollection
		err = callBrouter(query, geojson, 17777, "trekking")
		if err != nil {
			b.Logf("%d", err)
		}
	}
	if err != nil {
		fmt.Println(err)
	}
}
