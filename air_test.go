package skua

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/google/go-cmp/cmp"
)

// openMeteoAirBody is a canned Open-Meteo air-quality response with unixtime.
const openMeteoAirBody = `{
  "current": {
    "time": 1000000000,
    "us_aqi": 42.0,
    "pm2_5": 8.1,
    "pm10": 12.0,
    "ozone": 60.0,
    "nitrogen_dioxide": 10.0,
    "uv_index": 3.2
  }
}`

// TestOpenMeteoAir verifies normalization of a canned air-quality response.
func TestOpenMeteoAir(t *testing.T) {
	t.Parallel()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(openMeteoAirBody))
	}))
	defer srv.Close()

	got, err := NewOpenMeteoAir(WithAirBaseURL(srv.URL)).AirQuality(context.Background(), Location{Lat: 30.27, Lon: -97.74})
	if err != nil {
		t.Fatalf("AirQuality: %v", err)
	}
	want := AirQuality{
		Time:     time.Unix(1000000000, 0).UTC(),
		Category: "Good",
		USAQI:    42,
		PM25:     8.1,
		PM10:     12.0,
		Ozone:    60.0,
		NO2:      10.0,
		UVIndex:  3.2,
	}
	if diff := cmp.Diff(want, got); diff != "" {
		t.Errorf("air quality mismatch (-want +got):\n%s", diff)
	}
}

// TestOpenMeteoAirError covers non-200 responses and invalid locations.
func TestOpenMeteoAirError(t *testing.T) {
	t.Parallel()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer srv.Close()
	p := NewOpenMeteoAir(WithAirBaseURL(srv.URL))
	if _, err := p.AirQuality(context.Background(), Location{Lat: 1, Lon: 1}); !errors.Is(err, ErrProvider) {
		t.Errorf("non-200: want ErrProvider, got %v", err)
	}
	if _, err := p.AirQuality(context.Background(), Location{Lat: 200, Lon: 1}); !errors.Is(err, ErrLocation) {
		t.Errorf("bad location: want ErrLocation, got %v", err)
	}
}

// TestAQICategory checks the US AQI band mapping.
func TestAQICategory(t *testing.T) {
	t.Parallel()
	tests := []struct {
		WantCategory string
		AQI          int
	}{
		{WantCategory: "Good", AQI: 20},                            // Test 0: Good.
		{WantCategory: "Moderate", AQI: 75},                        // Test 1: Moderate.
		{WantCategory: "Unhealthy for sensitive groups", AQI: 130}, // Test 2: Sensitive.
		{WantCategory: "Unhealthy", AQI: 180},                      // Test 3: Unhealthy.
		{WantCategory: "Very unhealthy", AQI: 260},                 // Test 4: Very unhealthy.
		{WantCategory: "Hazardous", AQI: 400},                      // Test 5: Hazardous.
	}
	for testNum, test := range tests {
		t.Run(fmt.Sprintf("test %d", testNum), func(t *testing.T) {
			t.Parallel()
			if got := aqiCategory(test.AQI); got != test.WantCategory {
				t.Errorf("aqiCategory(%d) = %q, want %q", test.AQI, got, test.WantCategory)
			}
		})
	}
}
