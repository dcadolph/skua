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

// nwsAlertsBody is a canned NWS active-alerts response with two alerts listed
// least severe first, to exercise the sort.
const nwsAlertsBody = `{
  "features": [
    {
      "properties": {
        "event": "Heat Advisory",
        "headline": "Heat Advisory until 8 PM",
        "severity": "Moderate",
        "urgency": "Expected",
        "areaDesc": "Travis, TX",
        "onset": "2026-07-19T12:00:00-05:00",
        "ends": null,
        "expires": "2026-07-20T01:00:00-05:00",
        "description": "Hot.",
        "instruction": "Drink water."
      }
    },
    {
      "properties": {
        "event": "Flood Warning",
        "headline": "Flood Warning until 7:28 PM",
        "severity": "Severe",
        "urgency": "Immediate",
        "areaDesc": "Webb, TX",
        "onset": "2026-07-19T21:07:00-05:00",
        "ends": "2026-07-20T19:28:00-05:00",
        "expires": "2026-07-20T12:15:00-05:00",
        "description": "Flooding ongoing.",
        "instruction": "Turn around."
      }
    }
  ]
}`

// TestNWSAlerts verifies normalization, the ends fallback, and severity order.
func TestNWSAlerts(t *testing.T) {
	t.Parallel()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("User-Agent") == "" {
			t.Error("missing User-Agent header")
		}
		_, _ = w.Write([]byte(nwsAlertsBody))
	}))
	defer srv.Close()

	got, err := NewNWSAlerts(WithAlertsBaseURL(srv.URL)).Alerts(context.Background(), Location{Lat: 27.51, Lon: -99.51})
	if err != nil {
		t.Fatalf("Alerts: %v", err)
	}
	want := Alerts{Alerts: []Alert{
		{
			Event:       "Flood Warning",
			Headline:    "Flood Warning until 7:28 PM",
			Severity:    "Severe",
			Urgency:     "Immediate",
			Area:        "Webb, TX",
			Onset:       time.Date(2026, 7, 20, 2, 7, 0, 0, time.UTC),
			Ends:        time.Date(2026, 7, 21, 0, 28, 0, 0, time.UTC),
			Description: "Flooding ongoing.",
			Instruction: "Turn around.",
		},
		{
			Event:       "Heat Advisory",
			Headline:    "Heat Advisory until 8 PM",
			Severity:    "Moderate",
			Urgency:     "Expected",
			Area:        "Travis, TX",
			Onset:       time.Date(2026, 7, 19, 17, 0, 0, 0, time.UTC),
			Ends:        time.Date(2026, 7, 20, 6, 0, 0, 0, time.UTC),
			Description: "Hot.",
			Instruction: "Drink water.",
		},
	}}
	if diff := cmp.Diff(want, got); diff != "" {
		t.Errorf("alerts mismatch (-want +got):\n%s", diff)
	}
}

// TestNWSAlertsUncovered treats the 400 for out-of-coverage points as empty.
func TestNWSAlertsUncovered(t *testing.T) {
	t.Parallel()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusBadRequest)
	}))
	defer srv.Close()
	got, err := NewNWSAlerts(WithAlertsBaseURL(srv.URL)).Alerts(context.Background(), Location{Lat: 64.15, Lon: -21.94})
	if err != nil {
		t.Fatalf("Alerts: %v", err)
	}
	if len(got.Alerts) != 0 {
		t.Errorf("alerts = %+v, want empty", got.Alerts)
	}
}

// TestNWSAlertsErrors covers a server error and an invalid location.
func TestNWSAlertsErrors(t *testing.T) {
	t.Parallel()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer srv.Close()
	p := NewNWSAlerts(WithAlertsBaseURL(srv.URL))
	if _, err := p.Alerts(context.Background(), Location{Lat: 1, Lon: 1}); !errors.Is(err, ErrProvider) {
		t.Errorf("non-200: want ErrProvider, got %v", err)
	}
	if _, err := p.Alerts(context.Background(), Location{Lat: 200, Lon: 1}); !errors.Is(err, ErrLocation) {
		t.Errorf("bad location: want ErrLocation, got %v", err)
	}
}

// TestSeverityRank checks the severity ordering.
func TestSeverityRank(t *testing.T) {
	t.Parallel()
	tests := []struct {
		Severity string
		WantRank int
	}{
		{Severity: "Extreme", WantRank: 0},  // Test 0: Extreme first.
		{Severity: "Severe", WantRank: 1},   // Test 1: Severe.
		{Severity: "Moderate", WantRank: 2}, // Test 2: Moderate.
		{Severity: "Minor", WantRank: 3},    // Test 3: Minor.
		{Severity: "Unknown", WantRank: 4},  // Test 4: Unknown last.
		{Severity: "", WantRank: 4},         // Test 5: Empty treated as unknown.
	}
	for testNum, test := range tests {
		t.Run(fmt.Sprintf("test %d", testNum), func(t *testing.T) {
			t.Parallel()
			if got := severityRank(test.Severity); got != test.WantRank {
				t.Errorf("severityRank(%q) = %d, want %d", test.Severity, got, test.WantRank)
			}
		})
	}
}
