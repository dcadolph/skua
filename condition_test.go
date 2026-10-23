package skua

import (
	"fmt"
	"testing"
)

// TestConditionForCode checks known and unknown WMO code mappings.
func TestConditionForCode(t *testing.T) {
	t.Parallel()
	tests := []struct {
		WantCondition string
		Code          int
	}{
		{WantCondition: "Clear", Code: 0},         // Test 0: Clear sky.
		{WantCondition: "Partly cloudy", Code: 2}, // Test 1: Partly cloudy.
		{WantCondition: "Heavy rain", Code: 65},   // Test 2: Heavy rain.
		{WantCondition: "Thunderstorm", Code: 95}, // Test 3: Thunderstorm.
		{WantCondition: "Unknown", Code: 1234},    // Test 4: Unmapped code.
	}
	for testNum, test := range tests {
		t.Run(fmt.Sprintf("test %d", testNum), func(t *testing.T) {
			t.Parallel()
			got := conditionForCode(test.Code)
			if got != test.WantCondition {
				t.Errorf("conditionForCode(%d) = %q, want %q", test.Code, got, test.WantCondition)
			}
		})
	}
}
