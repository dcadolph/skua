package skua

import (
	"fmt"
	"math"
	"testing"
	"time"
)

// TestMoonAt checks the phase math against known lunar moments.
func TestMoonAt(t *testing.T) {
	t.Parallel()
	tests := []struct {
		Time     time.Time
		WantName string
	}{{ // Test 0: The reference epoch is a new moon.
		Time: time.Date(2000, 1, 6, 18, 14, 0, 0, time.UTC), WantName: "New moon",
	}, { // Test 1: Half a cycle later is a full moon.
		Time: time.Date(2000, 1, 21, 12, 40, 0, 0, time.UTC), WantName: "Full moon",
	}, { // Test 2: A quarter cycle in is the first quarter.
		Time: time.Date(2000, 1, 14, 3, 30, 0, 0, time.UTC), WantName: "First quarter",
	}, { // Test 3: A known modern full moon, July 10, 2025.
		Time: time.Date(2025, 7, 10, 20, 37, 0, 0, time.UTC), WantName: "Full moon",
	}}
	for testNum, test := range tests {
		t.Run(fmt.Sprintf("test %d", testNum), func(t *testing.T) {
			t.Parallel()
			got := moonAt(test.Time)
			if got.Name != test.WantName {
				t.Errorf("moonAt(%s).Name = %q (phase %.3f), want %q",
					test.Time.Format(time.RFC3339), got.Name, got.Phase, test.WantName)
			}
			if got.Phase < 0 || got.Phase >= 1 {
				t.Errorf("phase %f out of range", got.Phase)
			}
			if got.Illumination < 0 || got.Illumination > 1 {
				t.Errorf("illumination %f out of range", got.Illumination)
			}
		})
	}
}

// TestMoonIllumination pins the extremes: dark at new, lit at full.
func TestMoonIllumination(t *testing.T) {
	t.Parallel()
	newMoon := moonAt(time.Date(2000, 1, 6, 18, 14, 0, 0, time.UTC))
	if newMoon.Illumination > 0.01 {
		t.Errorf("new moon illumination = %f, want near 0", newMoon.Illumination)
	}
	full := moonAt(time.Date(2000, 1, 21, 12, 40, 0, 0, time.UTC))
	if math.Abs(full.Illumination-1) > 0.01 {
		t.Errorf("full moon illumination = %f, want near 1", full.Illumination)
	}
}
