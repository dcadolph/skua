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

// lh builds a lightning hour at hoursAhead from now with a code and CAPE.
func lh(now time.Time, hoursAhead, code int, cape float64) lightningHour {
	return lightningHour{
		time: now.Add(time.Duration(hoursAhead) * time.Hour),
		code: code,
		cape: cape,
	}
}

// TestAssessLightning covers each risk band and the imminent and horizon edges.
func TestAssessLightning(t *testing.T) {
	t.Parallel()
	base := time.Unix(1000000000, 0).UTC()
	tests := []struct {
		Name         string
		In           []lightningHour
		WantRisk     string
		WantLevel    int
		WantImminent bool
		WantHasNext  bool
	}{
		{Name: "quiet", In: []lightningHour{lh(base, 1, 0, 500), lh(base, 3, 0, 600)},
			WantRisk: "none", WantLevel: 0}, // Test 0: Calm and stable.
		{Name: "unstable", In: []lightningHour{lh(base, 2, 0, 2200), lh(base, 4, 0, 1800)},
			WantRisk: "low", WantLevel: 1}, // Test 1: High CAPE, no coded storm.
		{Name: "moderate", In: []lightningHour{lh(base, 4, 95, 1500)},
			WantRisk: "moderate", WantLevel: 2, WantHasNext: true}, // Test 2: Coded storm ahead.
		{Name: "imminent", In: []lightningHour{lh(base, 1, 95, 1500)},
			WantRisk: "moderate", WantLevel: 2, WantImminent: true, WantHasNext: true}, // Test 3: Storm within two hours.
		{Name: "high", In: []lightningHour{lh(base, 3, 95, 2600)},
			WantRisk: "high", WantLevel: 3, WantHasNext: true}, // Test 4: Strong instability.
		{Name: "hail", In: []lightningHour{lh(base, 3, 96, 1200)},
			WantRisk: "high", WantLevel: 3, WantHasNext: true}, // Test 5: Hail bumps the band.
		{Name: "extreme", In: []lightningHour{lh(base, 3, 99, 3200)},
			WantRisk: "extreme", WantLevel: 4, WantHasNext: true}, // Test 6: Heavy storm, extreme CAPE.
		{Name: "beyond horizon", In: []lightningHour{lh(base, 15, 95, 2600)},
			WantRisk: "none", WantLevel: 0}, // Test 7: Storm past the risk window.
	}
	for testNum, test := range tests {
		t.Run(fmt.Sprintf("test %d %s", testNum, test.Name), func(t *testing.T) {
			t.Parallel()
			got := assessLightning(test.In, base)
			if got.Risk != test.WantRisk || got.Level != test.WantLevel {
				t.Errorf("risk=%q level=%d, want %q %d", got.Risk, got.Level, test.WantRisk, test.WantLevel)
			}
			if got.Imminent != test.WantImminent {
				t.Errorf("imminent=%v, want %v", got.Imminent, test.WantImminent)
			}
			if got.HasNext != test.WantHasNext {
				t.Errorf("hasNext=%v, want %v", got.HasNext, test.WantHasNext)
			}
			if got.Headline == "" {
				t.Error("want a non-empty headline")
			}
		})
	}
}

// TestOpenMeteoLightning verifies a fetch and grade of a canned storm response.
func TestOpenMeteoLightning(t *testing.T) {
	t.Parallel()
	body := `{"hourly":{
	  "time":[1000000000,1000003600,1000007200,1000010800],
	  "weather_code":[0,0,95,95],
	  "cape":[500,800,2600,2400],
	  "lightning_potential":[null,null,null,null]
	}}`
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(body))
	}))
	defer srv.Close()

	base := time.Unix(1000000000, 0).UTC()
	p := NewOpenMeteoLightning(
		WithLightningBaseURL(srv.URL),
		WithLightningClock(func() time.Time { return base }),
	)
	got, err := p.Lightning(context.Background(), Location{Lat: 30.27, Lon: -97.74})
	if err != nil {
		t.Fatalf("Lightning: %v", err)
	}
	want := Lightning{
		Risk:           "high",
		Level:          3,
		Imminent:       false,
		Next:           base.Add(2 * time.Hour),
		HasNext:        true,
		PeakCapeJPerKg: 2600,
		StormHours:     2,
		Headline:       "Strong storms are brewing. Lightning is likely.",
	}
	if diff := cmp.Diff(want, got); diff != "" {
		t.Errorf("lightning mismatch (-want +got):\n%s", diff)
	}
}

// TestOpenMeteoLightningError covers a server error and an invalid location.
func TestOpenMeteoLightningError(t *testing.T) {
	t.Parallel()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer srv.Close()
	p := NewOpenMeteoLightning(WithLightningBaseURL(srv.URL))
	if _, err := p.Lightning(context.Background(), Location{Lat: 1, Lon: 1}); !errors.Is(err, ErrProvider) {
		t.Errorf("non-200: want ErrProvider, got %v", err)
	}
	if _, err := p.Lightning(context.Background(), Location{Lat: 200, Lon: 1}); !errors.Is(err, ErrLocation) {
		t.Errorf("bad location: want ErrLocation, got %v", err)
	}
}
