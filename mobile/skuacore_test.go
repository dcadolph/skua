package skuacore

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"slices"
	"testing"
	"time"

	"github.com/dcadolph/skua"
)

// testForecastJSON encodes a forecast with the given condition and precipitation.
func testForecastJSON(t *testing.T, condition string, precipMM float64, isDay bool) string {
	t.Helper()
	fc := skua.Forecast{
		Source:   "test",
		Location: skua.Location{Lat: 30.27, Lon: -97.74},
		Current: skua.Current{
			Time:          time.Date(2026, 10, 19, 15, 0, 0, 0, time.UTC),
			Condition:     condition,
			TempC:         18,
			ApparentTempC: 18,
			PrecipMM:      precipMM,
			IsDay:         isDay,
		},
	}
	b, err := json.Marshal(fc)
	if err != nil {
		t.Fatalf("marshal forecast: %v", err)
	}
	return string(b)
}

// testClearLines returns every clear-sky line the bank can say at the level.
func testClearLines(t *testing.T, level string) []string {
	t.Helper()
	var lines []string
	for _, day := range []bool{true, false} {
		for _, cond := range []string{"Clear", "Clear sky"} {
			var fc skua.Forecast
			if err := json.Unmarshal([]byte(testForecastJSON(t, cond, 0, day)), &fc); err != nil {
				t.Fatalf("unmarshal forecast: %v", err)
			}
			// Vary the date so every line in the bank is reached.
			for d := range 60 {
				fc.Current.Time = fc.Current.Time.AddDate(0, 0, d)
				v, err := skua.NewTemplateVoicer().Speak(context.Background(), fc,
					skua.VoiceOpts{Level: skua.ParseVoiceLevel(level), Imperial: true})
				if err != nil {
					t.Fatalf("speak: %v", err)
				}
				lines = append(lines, v.Line)
			}
		}
	}
	return lines
}

func TestVoiceSpeaksFromForecast(t *testing.T) {
	t.Parallel()
	tests := []struct {
		Level         string
		Condition     string
		PrecipMM      float64
		WantClearLine bool
	}{
		{ // Test 0: Heavy rain at dry level is not a clear-sky line.
			Level: "dry", Condition: "Heavy Rain", PrecipMM: 4, WantClearLine: false,
		},
		{ // Test 1: Heavy rain at proper level is not a clear-sky line.
			Level: "proper", Condition: "Heavy Rain", PrecipMM: 4, WantClearLine: false,
		},
		{ // Test 2: Clear sky speaks from the clear bank.
			Level: "dry", Condition: "Clear", PrecipMM: 0, WantClearLine: true,
		},
	}
	for testNum, test := range tests {
		t.Run(fmt.Sprintf("test %d", testNum), func(t *testing.T) {
			t.Parallel()
			out, err := Voice(testForecastJSON(t, test.Condition, test.PrecipMM, true),
				test.Level, "imperial", "", "", 0)
			if err != nil {
				t.Fatalf("Voice: %v", err)
			}
			var got skua.Voice
			if err := json.Unmarshal([]byte(out), &got); err != nil {
				t.Fatalf("unmarshal voice: %v", err)
			}
			if got.Line == "" {
				t.Fatal("empty line")
			}
			isClear := slices.Contains(testClearLines(t, test.Level), got.Line)
			if isClear != test.WantClearLine {
				t.Errorf("line %q: from clear bank = %v, want %v", got.Line, isClear, test.WantClearLine)
			}
		})
	}
}

func TestVoiceBadJSON(t *testing.T) {
	t.Parallel()
	tests := []struct {
		Run  func() (string, error)
		Want error
	}{
		{ // Test 0: Voice rejects malformed JSON.
			Run:  func() (string, error) { return Voice("{nope", "dry", "metric", "", "", 0) },
			Want: skua.ErrProvider,
		},
		{ // Test 1: PartyVoice rejects malformed JSON.
			Run: func() (string, error) {
				return PartyVoice("", "bachelorette", "mild", "metric", 21, "", "", 0)
			},
			Want: skua.ErrProvider,
		},
	}
	for testNum, test := range tests {
		t.Run(fmt.Sprintf("test %d", testNum), func(t *testing.T) {
			t.Parallel()
			if _, err := test.Run(); !errors.Is(err, test.Want) {
				t.Errorf("error = %v, want %v", err, test.Want)
			}
		})
	}
}

func TestPartyVoiceFromForecast(t *testing.T) {
	t.Parallel()
	out, err := PartyVoice(testForecastJSON(t, "Heavy Rain", 4, true),
		"bachelorette", "mild", "imperial", 21, "", "", 0)
	if err != nil {
		t.Fatalf("PartyVoice: %v", err)
	}
	var got skua.Voice
	if err := json.Unmarshal([]byte(out), &got); err != nil {
		t.Fatalf("unmarshal voice: %v", err)
	}
	if got.Line == "" || got.Briefing == "" {
		t.Errorf("empty voice: %+v", got)
	}
}
