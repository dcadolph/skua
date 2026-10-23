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

// swpcKpBody is a canned NOAA planetary K-index feed: a time-ordered list of
// readings, newest last, with a numeric Kp.
const swpcKpBody = `[
  {"time_tag":"2026-07-15T00:00:00","Kp":2.00,"a_running":7,"station_count":8},
  {"time_tag":"2026-07-15T03:00:00","Kp":6.00,"a_running":30,"station_count":8}
]`

// TestSWPCAurora parses the latest Kp and derives level and visibility.
func TestSWPCAurora(t *testing.T) {
	t.Parallel()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(swpcKpBody))
	}))
	defer srv.Close()

	got, err := NewSWPCAurora(WithAuroraBaseURL(srv.URL)).Aurora(context.Background(), Location{Lat: 65, Lon: 18})
	if err != nil {
		t.Fatalf("Aurora: %v", err)
	}
	want := Aurora{
		Time:    time.Date(2026, 7, 15, 3, 0, 0, 0, time.UTC),
		Kp:      6,
		Level:   "Moderate storm (G2)",
		Visible: true,
	}
	if diff := cmp.Diff(want, got); diff != "" {
		t.Errorf("aurora mismatch (-want +got):\n%s", diff)
	}
}

// TestSWPCAuroraError covers a server error, an empty feed, and a bad location.
func TestSWPCAuroraError(t *testing.T) {
	t.Parallel()
	bad := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer bad.Close()
	if _, err := NewSWPCAurora(WithAuroraBaseURL(bad.URL)).Aurora(context.Background(), Location{Lat: 65, Lon: 18}); !errors.Is(err, ErrProvider) {
		t.Errorf("non-200: want ErrProvider, got %v", err)
	}
	empty := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`[]`))
	}))
	defer empty.Close()
	if _, err := NewSWPCAurora(WithAuroraBaseURL(empty.URL)).Aurora(context.Background(), Location{Lat: 65, Lon: 18}); !errors.Is(err, ErrProvider) {
		t.Errorf("empty feed: want ErrProvider, got %v", err)
	}
	if _, err := NewSWPCAurora(WithAuroraBaseURL(bad.URL)).Aurora(context.Background(), Location{Lat: 200, Lon: 1}); !errors.Is(err, ErrLocation) {
		t.Errorf("bad location: want ErrLocation, got %v", err)
	}
}

// TestAuroraLevel checks the Kp band mapping.
func TestAuroraLevel(t *testing.T) {
	t.Parallel()
	tests := []struct {
		WantLevel string
		Kp        float64
	}{
		{WantLevel: "Quiet", Kp: 1},               // Test 0: Quiet.
		{WantLevel: "Unsettled", Kp: 3},           // Test 1: Unsettled.
		{WantLevel: "Active", Kp: 4},              // Test 2: Active.
		{WantLevel: "Minor storm (G1)", Kp: 5},    // Test 3: G1.
		{WantLevel: "Moderate storm (G2)", Kp: 6}, // Test 4: G2.
		{WantLevel: "Strong storm (G3)", Kp: 7},   // Test 5: G3.
		{WantLevel: "Severe storm (G4)", Kp: 8},   // Test 6: G4.
		{WantLevel: "Extreme storm (G5)", Kp: 9},  // Test 7: G5.
	}
	for testNum, test := range tests {
		t.Run(fmt.Sprintf("test %d", testNum), func(t *testing.T) {
			t.Parallel()
			if got := auroraLevel(test.Kp); got != test.WantLevel {
				t.Errorf("auroraLevel(%v) = %q, want %q", test.Kp, got, test.WantLevel)
			}
		})
	}
}

// TestAuroraVisible checks the latitude boundary against Kp.
func TestAuroraVisible(t *testing.T) {
	t.Parallel()
	tests := []struct {
		Kp   float64
		Lat  float64
		Want bool
	}{
		{Kp: 0, Lat: 70, Want: true},  // Test 0: High lat, quiet, still poleward of the boundary.
		{Kp: 0, Lat: 45, Want: false}, // Test 1: Mid lat, quiet, no.
		{Kp: 6, Lat: 55, Want: true},  // Test 2: Storm lowers the boundary to 54.
		{Kp: 6, Lat: 50, Want: false}, // Test 3: Just equatorward of the boundary.
		{Kp: 9, Lat: -50, Want: true}, // Test 4: Southern high lat, extreme storm.
	}
	for testNum, test := range tests {
		t.Run(fmt.Sprintf("test %d", testNum), func(t *testing.T) {
			t.Parallel()
			if got := auroraVisible(test.Kp, test.Lat); got != test.Want {
				t.Errorf("auroraVisible(%v, %v) = %v, want %v", test.Kp, test.Lat, got, test.Want)
			}
		})
	}
}
