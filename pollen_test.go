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
	"github.com/google/go-cmp/cmp/cmpopts"
)

// pollenDotComBody is a canned Pollen.com current pollen response.
const pollenDotComBody = `{
  "ForecastDate": "2026-09-08T00:00:00-04:00",
  "Location": {
    "ZIP": "78701",
    "City": "AUSTIN",
    "State": "TX",
    "periods": [
      {"Type": "Yesterday", "Index": 9.1, "Triggers": [{"Name": "Ragweed", "Genus": "Ambrosia", "PlantType": "Ragweed"}]},
      {"Type": "Today", "Index": 6.1, "Triggers": [{"Name": "Grasses", "Genus": "Poaceae", "PlantType": "Grasses"}, {"Name": "Ragweed", "Genus": "Ambrosia", "PlantType": "Ragweed"}]},
      {"Type": "Tomorrow", "Index": 7.9, "Triggers": [{"Name": "Elm", "Genus": "Ulmus", "PlantType": "Trees"}]}
    ]
  }
}`

// TestPollenDotCom verifies normalization of a canned pollen response.
func TestPollenDotCom(t *testing.T) {
	t.Parallel()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(pollenDotComBody))
	}))
	defer srv.Close()

	got, err := NewPollenDotCom(WithPollenBaseURL(srv.URL+"/")).Pollen(context.Background(), "78701")
	if err != nil {
		t.Fatalf("Pollen: %v", err)
	}
	want := Pollen{
		Date:  time.Date(2026, 9, 8, 0, 0, 0, 0, time.FixedZone("", -4*60*60)),
		ZIP:   "78701",
		City:  "AUSTIN",
		State: "TX",
		Today: PollenDay{
			Index:    6.1,
			Category: "Moderate",
			Triggers: []string{"Grasses", "Ragweed"},
		},
		Tomorrow: PollenDay{
			Index:    7.9,
			Category: "High",
			Triggers: []string{"Elm"},
		},
	}
	if diff := cmp.Diff(want, got, cmpopts.EquateEmpty()); diff != "" {
		t.Errorf("pollen mismatch (-want +got):\n%s", diff)
	}
}

// TestPollenDotComError covers non-200 responses and an empty ZIP.
func TestPollenDotComError(t *testing.T) {
	t.Parallel()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusForbidden)
	}))
	defer srv.Close()
	p := NewPollenDotCom(WithPollenBaseURL(srv.URL + "/"))
	if _, err := p.Pollen(context.Background(), "78701"); !errors.Is(err, ErrProvider) {
		t.Errorf("non-200: want ErrProvider, got %v", err)
	}
	if _, err := p.Pollen(context.Background(), ""); !errors.Is(err, ErrProvider) {
		t.Errorf("empty zip: want ErrProvider, got %v", err)
	}
}

// TestPollenCategory checks the pollen index band mapping.
func TestPollenCategory(t *testing.T) {
	t.Parallel()
	tests := []struct {
		WantCategory string
		Index        float64
	}{
		{WantCategory: "Low", Index: 1.0},          // Test 0: Low.
		{WantCategory: "Low-Moderate", Index: 3.5}, // Test 1: Low-Moderate.
		{WantCategory: "Moderate", Index: 6.1},     // Test 2: Moderate.
		{WantCategory: "High", Index: 7.9},         // Test 3: High.
		{WantCategory: "Very High", Index: 11.0},   // Test 4: Very High.
	}
	for testNum, test := range tests {
		t.Run(fmt.Sprintf("test %d", testNum), func(t *testing.T) {
			t.Parallel()
			if got := pollenCategory(test.Index); got != test.WantCategory {
				t.Errorf("pollenCategory(%v) = %q, want %q", test.Index, got, test.WantCategory)
			}
		})
	}
}
