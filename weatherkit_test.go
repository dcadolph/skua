package skua

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/google/go-cmp/cmp"
	"github.com/google/go-cmp/cmp/cmpopts"
)

// weatherKitTestBody is a canned WeatherKit response with RFC3339 timestamps.
const weatherKitTestBody = `{
  "currentWeather": {
    "asOf": "2026-07-14T22:00:00Z",
    "conditionCode": "MostlyCloudy",
    "temperature": 26.1,
    "temperatureApparent": 28.0,
    "humidity": 0.62,
    "precipitationIntensity": 0.0,
    "windSpeed": 12.0,
    "windDirection": 180,
    "daylight": true
  },
  "forecastHourly": {
    "hours": [
      {"forecastStart":"2026-07-14T22:00:00Z","conditionCode":"MostlyCloudy","temperature":26.0,"precipitationChance":0.1,"precipitationAmount":0.0,"windSpeed":12.0},
      {"forecastStart":"2026-07-14T23:00:00Z","conditionCode":"Rain","temperature":24.0,"precipitationChance":0.5,"precipitationAmount":0.4,"windSpeed":14.0}
    ]
  },
  "forecastDaily": {
    "days": [
      {"forecastStart":"2026-07-14T05:00:00Z","conditionCode":"Rain","temperatureMax":31.0,"temperatureMin":23.0,"precipitationChance":0.6,"sunrise":"2026-07-14T11:39:00Z","sunset":"2026-07-15T01:34:00Z","maxUvIndex":8}
    ]
  }
}`

// TestWeatherKitForecast verifies auth, endpoint, and normalization.
func TestWeatherKitForecast(t *testing.T) {
	t.Parallel()
	pemBytes, _ := testKeyPEM(t)
	var gotAuth, gotPath string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotAuth = r.Header.Get("Authorization")
		gotPath = r.URL.Path
		_, _ = w.Write([]byte(weatherKitTestBody))
	}))
	defer srv.Close()

	p, err := NewWeatherKit("TEAM", "com.skua", "KEY", pemBytes, WithWKBaseURL(srv.URL))
	if err != nil {
		t.Fatalf("NewWeatherKit: %v", err)
	}
	got, err := p.Forecast(context.Background(), Location{Lat: 30.27, Lon: -97.74})
	if err != nil {
		t.Fatalf("Forecast: %v", err)
	}
	if !strings.HasPrefix(gotAuth, "Bearer ") {
		t.Errorf("Authorization = %q, want a Bearer token", gotAuth)
	}
	if !strings.Contains(gotPath, "/api/v1/weather/en/") {
		t.Errorf("path = %q, want the weather endpoint", gotPath)
	}

	want := Forecast{
		Source:   "weatherkit",
		Moon:     moonAt(time.Date(2026, 7, 14, 22, 0, 0, 0, time.UTC)),
		Location: Location{Lat: 30.27, Lon: -97.74},
		Current: Current{
			Time:          time.Date(2026, 7, 14, 22, 0, 0, 0, time.UTC),
			Condition:     "Mostly Cloudy",
			TempC:         26.1,
			ApparentTempC: 28.0,
			PrecipMM:      0,
			WindKph:       12,
			Humidity:      62,
			WindDirDeg:    180,
			IsDay:         true,
		},
		Hourly: []HourlyPoint{
			{Time: time.Date(2026, 7, 14, 22, 0, 0, 0, time.UTC), Condition: "Mostly Cloudy", TempC: 26.0, PrecipMM: 0, WindKph: 12, PrecipProb: 10},
			{Time: time.Date(2026, 7, 14, 23, 0, 0, 0, time.UTC), Condition: "Rain", TempC: 24.0, PrecipMM: 0.4, WindKph: 14, PrecipProb: 50},
		},
		Daily: []DailyPoint{
			{
				Date:       time.Date(2026, 7, 14, 5, 0, 0, 0, time.UTC),
				Sunrise:    time.Date(2026, 7, 14, 11, 39, 0, 0, time.UTC),
				Sunset:     time.Date(2026, 7, 15, 1, 34, 0, 0, time.UTC),
				Condition:  "Rain",
				HighC:      31,
				LowC:       23,
				UVIndexMax: 8,
				PrecipProb: 60,
			},
		},
	}
	if diff := cmp.Diff(want, got, cmpopts.EquateEmpty()); diff != "" {
		t.Errorf("forecast mismatch (-want +got):\n%s", diff)
	}
}

// TestWeatherKitError maps a non-200 response to ErrProvider.
func TestWeatherKitError(t *testing.T) {
	t.Parallel()
	pemBytes, _ := testKeyPEM(t)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusUnauthorized)
	}))
	defer srv.Close()
	p, err := NewWeatherKit("T", "s", "K", pemBytes, WithWKBaseURL(srv.URL))
	if err != nil {
		t.Fatalf("NewWeatherKit: %v", err)
	}
	if _, err := p.Forecast(context.Background(), Location{Lat: 1, Lon: 1}); !errors.Is(err, ErrProvider) {
		t.Errorf("want ErrProvider, got %v", err)
	}
}

// TestHumanizeCondition splits WeatherKit condition codes into readable text.
func TestHumanizeCondition(t *testing.T) {
	t.Parallel()
	tests := []struct {
		In   string
		Want string
	}{
		{In: "MostlyCloudy", Want: "Mostly Cloudy"},
		{In: "Clear", Want: "Clear"},
		{In: "ScatteredThunderstorms", Want: "Scattered Thunderstorms"},
		{In: "", Want: "Unknown"},
	}
	for testNum, test := range tests {
		t.Run(fmt.Sprintf("test %d", testNum), func(t *testing.T) {
			t.Parallel()
			if got := humanizeCondition(test.In); got != test.Want {
				t.Errorf("humanizeCondition(%q) = %q, want %q", test.In, got, test.Want)
			}
		})
	}
}
