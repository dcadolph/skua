package skua

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/google/go-cmp/cmp"
)

// openMeteoMarineBody is a canned Open-Meteo marine response with unixtime.
const openMeteoMarineBody = `{
  "current": {
    "time": 1000000000,
    "wave_height": 1.4,
    "wave_direction": 210,
    "wave_period": 8.5,
    "swell_wave_height": 1.1,
    "swell_wave_period": 11.0
  }
}`

// TestOpenMeteoMarine verifies normalization of a canned coastal response.
func TestOpenMeteoMarine(t *testing.T) {
	t.Parallel()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(openMeteoMarineBody))
	}))
	defer srv.Close()

	got, err := NewOpenMeteoMarine(WithMarineBaseURL(srv.URL)).Marine(context.Background(), Location{Lat: 32.7, Lon: -117.2})
	if err != nil {
		t.Fatalf("Marine: %v", err)
	}
	want := Marine{
		Available:        true,
		Time:             time.Unix(1000000000, 0).UTC(),
		WaveHeightM:      1.4,
		WaveDirectionDeg: 210,
		WavePeriodS:      8.5,
		SwellHeightM:     1.1,
		SwellPeriodS:     11.0,
	}
	if diff := cmp.Diff(want, got); diff != "" {
		t.Errorf("marine mismatch (-want +got):\n%s", diff)
	}
}

// TestOpenMeteoMarineInland treats a 400 and a null wave height as unavailable.
func TestOpenMeteoMarineInland(t *testing.T) {
	t.Parallel()
	// Test 0: The API returns 400 for an inland point.
	four := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusBadRequest)
	}))
	defer four.Close()
	got, err := NewOpenMeteoMarine(WithMarineBaseURL(four.URL)).Marine(context.Background(), Location{Lat: 30.27, Lon: -97.74})
	if err != nil {
		t.Fatalf("400 case: unexpected error %v", err)
	}
	if got.Available {
		t.Error("400 case: want Available false")
	}
	// Test 1: A 200 with a null wave height is also unavailable.
	nul := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`{"current":{"time":1,"wave_height":null}}`))
	}))
	defer nul.Close()
	got, err = NewOpenMeteoMarine(WithMarineBaseURL(nul.URL)).Marine(context.Background(), Location{Lat: 30.27, Lon: -97.74})
	if err != nil {
		t.Fatalf("null case: unexpected error %v", err)
	}
	if got.Available {
		t.Error("null case: want Available false")
	}
}

// TestOpenMeteoMarineError covers a server error and an invalid location.
func TestOpenMeteoMarineError(t *testing.T) {
	t.Parallel()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer srv.Close()
	p := NewOpenMeteoMarine(WithMarineBaseURL(srv.URL))
	if _, err := p.Marine(context.Background(), Location{Lat: 1, Lon: 1}); !errors.Is(err, ErrProvider) {
		t.Errorf("non-200: want ErrProvider, got %v", err)
	}
	if _, err := p.Marine(context.Background(), Location{Lat: 200, Lon: 1}); !errors.Is(err, ErrLocation) {
		t.Errorf("bad location: want ErrLocation, got %v", err)
	}
}
