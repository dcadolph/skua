package skua

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/google/go-cmp/cmp"
	"github.com/google/go-cmp/cmp/cmpopts"
)

// openMeteoTestBody is a canned Open-Meteo response with unixtime timestamps.
const openMeteoTestBody = `{
  "utc_offset_seconds": 0,
  "current": {
    "time": 1000000000,
    "temperature_2m": 20.5,
    "relative_humidity_2m": 60,
    "apparent_temperature": 19.9,
    "is_day": 1,
    "precipitation": 0.0,
    "weather_code": 2,
    "wind_speed_10m": 12.0,
    "wind_direction_10m": 180
  },
  "minutely_15": {
    "time": [1000000000, 1000000900],
    "precipitation": [0.0, 0.4]
  },
  "hourly": {
    "time": [1000000000, 1000003600],
    "temperature_2m": [20.5, 21.0],
    "apparent_temperature": [19.0, 19.6],
    "surface_pressure": [1001.0, 1000.5],
    "precipitation_probability": [10, 20],
    "precipitation": [0.0, 0.1],
    "weather_code": [2, 61],
    "wind_speed_10m": [12.0, 13.0]
  },
  "daily": {
    "time": [1000000000],
    "weather_code": [61],
    "temperature_2m_max": [25.0],
    "temperature_2m_min": [15.0],
    "precipitation_probability_max": [40],
    "uv_index_max": [6.5],
    "sunrise": [1000020000],
    "sunset": [1000060000]
  }
}`

// TestOpenMeteoForecast verifies normalization of a canned Open-Meteo response.
func TestOpenMeteoForecast(t *testing.T) {
	t.Parallel()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(openMeteoTestBody))
	}))
	defer srv.Close()

	got, err := NewOpenMeteo(WithBaseURL(srv.URL)).Forecast(context.Background(), Location{Lat: 40, Lon: -74})
	if err != nil {
		t.Fatalf("Forecast: %v", err)
	}

	want := Forecast{
		Source:   "open-meteo",
		Location: Location{Lat: 40, Lon: -74},
		Moon:     moonAt(time.Unix(1000000000, 0).UTC()),
		Current: Current{
			Time:          time.Unix(1000000000, 0).UTC(),
			Condition:     "Partly cloudy",
			TempC:         20.5,
			ApparentTempC: 19.9,
			PrecipMM:      0,
			WindKph:       12,
			Humidity:      60,
			WindDirDeg:    180,
			IsDay:         true,
		},
		Minutely: []MinutelyPoint{
			{Time: time.Unix(1000000000, 0).UTC(), PrecipMM: 0},
			{Time: time.Unix(1000000900, 0).UTC(), PrecipMM: 0.4},
		},
		Hourly: []HourlyPoint{
			{Time: time.Unix(1000000000, 0).UTC(), Condition: "Partly cloudy", TempC: 20.5, ApparentTempC: 19.0, PressureHPa: 1001.0, PrecipMM: 0, WindKph: 12, PrecipProb: 10},
			{Time: time.Unix(1000003600, 0).UTC(), Condition: "Light rain", TempC: 21, ApparentTempC: 19.6, PressureHPa: 1000.5, PrecipMM: 0.1, WindKph: 13, PrecipProb: 20},
		},
		Daily: []DailyPoint{
			{
				Date:       time.Unix(1000000000, 0).UTC(),
				Sunrise:    time.Unix(1000020000, 0).UTC(),
				Sunset:     time.Unix(1000060000, 0).UTC(),
				Condition:  "Light rain",
				HighC:      25,
				LowC:       15,
				UVIndexMax: 6.5,
				PrecipProb: 40,
			},
		},
	}
	if diff := cmp.Diff(want, got, cmpopts.EquateEmpty()); diff != "" {
		t.Errorf("forecast mismatch (-want +got):\n%s", diff)
	}
}

// TestOpenMeteoErrors covers non-200 responses and invalid locations.
func TestOpenMeteoErrors(t *testing.T) {
	t.Parallel()

	// Test 0: A non-200 status yields ErrProvider.
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer srv.Close()
	p := NewOpenMeteo(WithBaseURL(srv.URL))
	if _, err := p.Forecast(context.Background(), Location{Lat: 1, Lon: 1}); !errors.Is(err, ErrProvider) {
		t.Errorf("non-200: want ErrProvider, got %v", err)
	}

	// Test 1: An out-of-range latitude yields ErrLocation before any request.
	if _, err := p.Forecast(context.Background(), Location{Lat: 200, Lon: 1}); !errors.Is(err, ErrLocation) {
		t.Errorf("bad location: want ErrLocation, got %v", err)
	}
}

// TestOpenMeteoYesterday peels the past day into Yesterday and trims past hours.
func TestOpenMeteoYesterday(t *testing.T) {
	t.Parallel()
	body := `{
  "current": {"time": 1000086400, "temperature_2m": 20.0, "weather_code": 0, "is_day": 1},
  "hourly": {"time": [1000000000, 1000083600, 1000087200], "temperature_2m": [15.0, 19.0, 21.0]},
  "daily": {"time": [1000000000, 1000086400], "weather_code": [61, 0],
    "temperature_2m_max": [22.0, 30.0], "temperature_2m_min": [12.0, 18.0]}
}`
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(body))
	}))
	defer srv.Close()
	got, err := NewOpenMeteo(WithBaseURL(srv.URL)).Forecast(context.Background(), Location{Lat: 40, Lon: -74})
	if err != nil {
		t.Fatalf("Forecast: %v", err)
	}
	if got.Yesterday == nil || got.Yesterday.HighC != 22 {
		t.Fatalf("yesterday = %+v, want high 22", got.Yesterday)
	}
	if len(got.Daily) != 1 || got.Daily[0].HighC != 30 {
		t.Errorf("daily = %+v, want single today row with high 30", got.Daily)
	}
	if len(got.Hourly) != 2 {
		t.Errorf("hourly kept %d rows, want 2 recent", len(got.Hourly))
	}
}
