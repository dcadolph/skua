package skua

import (
	"context"
	"errors"
	"fmt"
	"math"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"

	"github.com/google/go-cmp/cmp"
	"github.com/google/go-cmp/cmp/cmpopts"
)

// tideStationsBody is a canned CO-OPS station catalog with two coasts.
const tideStationsBody = `{"count":2,"stations":[
  {"id":"9410170","name":"San Diego","state":"CA","lat":32.7157,"lng":-117.1611},
  {"id":"9414290","name":"San Francisco","state":"CA","lat":37.8063,"lng":-122.4659}
]}`

// tidePredictionsBody is a canned day of high and low water in GMT.
const tidePredictionsBody = `{"predictions":[
  {"t":"2026-07-20 03:24","v":"5.12","type":"H"},
  {"t":"2026-07-20 09:41","v":"0.23","type":"L"},
  {"t":"2026-07-20 15:50","v":"4.80","type":"H"},
  {"t":"2026-07-20 21:58","v":"1.10","type":"L"}
]}`

// tideTime parses a CO-OPS timestamp as UTC.
func tideTime(t *testing.T, s string) time.Time {
	t.Helper()
	ts, err := time.Parse("2006-01-02 15:04", s)
	if err != nil {
		t.Fatalf("parse %q: %v", s, err)
	}
	return ts
}

// TestNOAATides verifies the nearest station and its normalized extremes.
func TestNOAATides(t *testing.T) {
	t.Parallel()
	stations := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(tideStationsBody))
	}))
	defer stations.Close()
	predict := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(tidePredictionsBody))
	}))
	defer predict.Close()

	p := NewNOAATides(
		WithTideStationsURL(stations.URL),
		WithTidePredictionsURL(predict.URL),
	)
	got, err := p.Tides(context.Background(), Location{Lat: 32.7, Lon: -117.2})
	if err != nil {
		t.Fatalf("Tides: %v", err)
	}
	want := Tides{
		Available:   true,
		StationID:   "9410170",
		StationName: "San Diego",
		State:       "CA",
		Datum:       "MLLW",
		Units:       "ft",
		Events: []TideEvent{
			{Time: tideTime(t, "2026-07-20 03:24"), Type: "high", HeightFt: 5.12},
			{Time: tideTime(t, "2026-07-20 09:41"), Type: "low", HeightFt: 0.23},
			{Time: tideTime(t, "2026-07-20 15:50"), Type: "high", HeightFt: 4.80},
			{Time: tideTime(t, "2026-07-20 21:58"), Type: "low", HeightFt: 1.10},
		},
	}
	if diff := cmp.Diff(want, got, cmpopts.IgnoreFields(Tides{}, "DistanceKM"), cmpopts.EquateEmpty()); diff != "" {
		t.Errorf("tides mismatch (-want +got):\n%s", diff)
	}
	if got.DistanceKM <= 0 || got.DistanceKM > 10 {
		t.Errorf("DistanceKM = %g, want a few km", got.DistanceKM)
	}
}

// TestNOAATidesInland reports unavailable and never calls predictions when the
// nearest station is out of range.
func TestNOAATidesInland(t *testing.T) {
	t.Parallel()
	stations := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(tideStationsBody))
	}))
	defer stations.Close()
	var predictCalls atomic.Int32
	predict := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		predictCalls.Add(1)
		_, _ = w.Write([]byte(tidePredictionsBody))
	}))
	defer predict.Close()

	p := NewNOAATides(
		WithTideStationsURL(stations.URL),
		WithTidePredictionsURL(predict.URL),
	)
	// Austin is far from both coastal stations.
	got, err := p.Tides(context.Background(), Location{Lat: 30.27, Lon: -97.74})
	if err != nil {
		t.Fatalf("Tides: %v", err)
	}
	if got.Available {
		t.Error("want Available false inland")
	}
	if n := predictCalls.Load(); n != 0 {
		t.Errorf("predictions calls = %d, want 0", n)
	}
}

// TestNOAATidesStationsError covers a station fetch failure and a bad location.
func TestNOAATidesStationsError(t *testing.T) {
	t.Parallel()
	stations := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer stations.Close()
	p := NewNOAATides(WithTideStationsURL(stations.URL))

	// Test 0: A failing station catalog is a provider error.
	if _, err := p.Tides(context.Background(), Location{Lat: 32.7, Lon: -117.2}); !errors.Is(err, ErrProvider) {
		t.Errorf("stations 500: want ErrProvider, got %v", err)
	}
	// Test 1: A bad location fails before any fetch.
	if _, err := p.Tides(context.Background(), Location{Lat: 200, Lon: 0}); !errors.Is(err, ErrLocation) {
		t.Errorf("bad location: want ErrLocation, got %v", err)
	}
}

// TestNOAATidesPredictionsError covers a non-200 and a CO-OPS error block.
func TestNOAATidesPredictionsError(t *testing.T) {
	t.Parallel()
	stations := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(tideStationsBody))
	}))
	defer stations.Close()

	// Test 0: Predictions return a server error.
	fail := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer fail.Close()
	p := NewNOAATides(WithTideStationsURL(stations.URL), WithTidePredictionsURL(fail.URL))
	if _, err := p.Tides(context.Background(), Location{Lat: 32.7, Lon: -117.2}); !errors.Is(err, ErrProvider) {
		t.Errorf("predictions 500: want ErrProvider, got %v", err)
	}

	// Test 1: Predictions return a CO-OPS error block with a 200.
	errBlock := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`{"error":{"message":"No data was found."}}`))
	}))
	defer errBlock.Close()
	p = NewNOAATides(WithTideStationsURL(stations.URL), WithTidePredictionsURL(errBlock.URL))
	if _, err := p.Tides(context.Background(), Location{Lat: 32.7, Lon: -117.2}); !errors.Is(err, ErrProvider) {
		t.Errorf("error block: want ErrProvider, got %v", err)
	}
}

// TestNearestTideStation checks nearest selection and the range cutoff.
func TestNearestTideStation(t *testing.T) {
	t.Parallel()
	catalog := []tideStation{
		{ID: "sd", Name: "San Diego", Lat: 32.7157, Lon: -117.1611},
		{ID: "sf", Name: "San Francisco", Lat: 37.8063, Lon: -122.4659},
	}
	tests := []struct {
		Stations []tideStation
		WantID   string
		In       Location
		MaxKM    float64
		WantOK   bool
	}{
		{Stations: catalog, In: Location{Lat: 32.7, Lon: -117.2}, MaxKM: 60, WantID: "sd", WantOK: true},  // Test 0: Picks the closer coast.
		{Stations: catalog, In: Location{Lat: 37.8, Lon: -122.45}, MaxKM: 60, WantID: "sf", WantOK: true}, // Test 1: Picks the other coast.
		{Stations: catalog, In: Location{Lat: 30.27, Lon: -97.74}, MaxKM: 60, WantOK: false},              // Test 2: Inland is out of range.
		{Stations: nil, In: Location{Lat: 32.7, Lon: -117.2}, MaxKM: 60, WantOK: false},                   // Test 3: Empty catalog.
	}
	for testNum, test := range tests {
		t.Run(fmt.Sprintf("test %d", testNum), func(t *testing.T) {
			t.Parallel()
			got, dist, ok := nearestTideStation(test.Stations, test.In, test.MaxKM)
			if ok != test.WantOK {
				t.Fatalf("ok = %v, want %v", ok, test.WantOK)
			}
			if ok {
				if got.ID != test.WantID {
					t.Errorf("id = %q, want %q", got.ID, test.WantID)
				}
				if dist < 0 || dist > test.MaxKM {
					t.Errorf("dist = %g, want within %g", dist, test.MaxKM)
				}
			}
		})
	}
}

// TestHaversineKM checks the distance helper against known separations.
func TestHaversineKM(t *testing.T) {
	t.Parallel()
	tests := []struct {
		Lat1, Lon1, Lat2, Lon2 float64
		WantKM                 float64
		Tol                    float64
	}{
		{0, 0, 0, 0, 0, 0.001},                 // Test 0: Same point.
		{0, 0, 0, 1, 111.19, 0.5},              // Test 1: One degree of longitude at the equator.
		{0, 0, 1, 0, 111.19, 0.5},              // Test 2: One degree of latitude.
		{32.7, -117.2, 32.7, -117.2, 0, 0.001}, // Test 3: A real coordinate against itself.
	}
	for testNum, test := range tests {
		t.Run(fmt.Sprintf("test %d", testNum), func(t *testing.T) {
			t.Parallel()
			got := haversineKM(test.Lat1, test.Lon1, test.Lat2, test.Lon2)
			if math.Abs(got-test.WantKM) > test.Tol {
				t.Errorf("haversineKM = %g, want %g +/- %g", got, test.WantKM, test.Tol)
			}
		})
	}
}
