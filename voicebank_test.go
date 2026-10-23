package skua

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/google/go-cmp/cmp"
)

// bankForecast builds a forecast fixture steered into a bucket.
func bankForecast(condition string, feels float64, isDay bool) Forecast {
	return Forecast{
		Source:   "test",
		Location: Location{Lat: 30.27, Lon: -97.74},
		Current: Current{
			Time:          time.Date(2026, 7, 19, 21, 0, 0, 0, time.UTC),
			Condition:     condition,
			TempC:         30,
			ApparentTempC: feels,
			WindKph:       10,
			WindGustKph:   18,
			IsDay:         isDay,
		},
		Daily: []DailyPoint{{HighC: 36, LowC: 24, Condition: condition, PrecipProb: 40}},
	}
}

// TestBucketFor classifies conditions into line bank buckets.
func TestBucketFor(t *testing.T) {
	t.Parallel()
	tests := []struct {
		Condition string
		Feels     float64
		IsDay     bool
		Wind      float64
		Want      voiceBucket
	}{
		{Condition: "Thunderstorm", Feels: 25, IsDay: true, Want: bucketStorm},   // Test 0: Storm.
		{Condition: "Light snow", Feels: -2, IsDay: true, Want: bucketSnow},      // Test 1: Snow.
		{Condition: "Light rain", Feels: 20, IsDay: true, Want: bucketRain},      // Test 2: Rain.
		{Condition: "Drizzle", Feels: 18, IsDay: true, Want: bucketDrizzle},      // Test 3: Drizzle.
		{Condition: "Fog", Feels: 12, IsDay: true, Want: bucketFog},              // Test 4: Fog.
		{Condition: "Clear", Feels: 40, IsDay: true, Want: bucketHot},            // Test 5: Heat beats clear.
		{Condition: "Clear", Feels: -5, IsDay: true, Want: bucketCold},           // Test 6: Cold beats clear.
		{Condition: "Overcast", Feels: 20, IsDay: true, Want: bucketOvercast},    // Test 7: Overcast.
		{Condition: "Partly cloudy", Feels: 22, IsDay: true, Want: bucketPartly}, // Test 8: Partly.
		{Condition: "Clear", Feels: 22, IsDay: true, Want: bucketClearDay},       // Test 9: Clear day.
		{Condition: "Clear", Feels: 22, IsDay: false, Want: bucketClearNight},    // Test 10: Clear night.
	}
	for testNum, test := range tests {
		t.Run(fmt.Sprintf("test %d", testNum), func(t *testing.T) {
			t.Parallel()
			f := bankForecast(test.Condition, test.Feels, test.IsDay)
			if got := bucketFor(f); got != test.Want {
				t.Errorf("bucketFor(%q, feels %.0f) = %q, want %q", test.Condition, test.Feels, got, test.Want)
			}
		})
	}
}

// TestBucketForPrecipRate confirms a measurable precipitation rate overrides a
// stale condition string, while snow and storms keep their own buckets.
func TestBucketForPrecipRate(t *testing.T) {
	t.Parallel()
	tests := []struct {
		Condition string
		PrecipMM  float64
		Want      voiceBucket
	}{
		{Condition: "Clear", PrecipMM: 2, Want: bucketRain},         // Test 0: Clear but raining.
		{Condition: "Overcast", PrecipMM: 0.1, Want: bucketRain},    // Test 1: Threshold rate.
		{Condition: "Clear", PrecipMM: 0.05, Want: bucketClearDay},  // Test 2: Below threshold.
		{Condition: "Snow", PrecipMM: 2, Want: bucketSnow},          // Test 3: Snow stays snow.
		{Condition: "Thunderstorm", PrecipMM: 2, Want: bucketStorm}, // Test 4: Storm stays storm.
	}
	for testNum, test := range tests {
		t.Run(fmt.Sprintf("test %d", testNum), func(t *testing.T) {
			t.Parallel()
			f := bankForecast(test.Condition, 20, true)
			f.Current.PrecipMM = test.PrecipMM
			if got := bucketFor(f); got != test.Want {
				t.Errorf("bucketFor(%q, %.2f mm) = %q, want %q", test.Condition, test.PrecipMM, got, test.Want)
			}
		})
	}
}

// TestBucketForWind picks the wind bucket on strong gusts.
func TestBucketForWind(t *testing.T) {
	t.Parallel()
	f := bankForecast("Clear", 20, true)
	f.Current.WindGustKph = 60
	if got := bucketFor(f); got != bucketWind {
		t.Errorf("bucketFor windy = %q, want %q", got, bucketWind)
	}
}

// TestTemplateVoicerSpeak confirms every bucket and level yields a filled line
// and briefing with no unrendered placeholders.
func TestTemplateVoicerSpeak(t *testing.T) {
	t.Parallel()
	v := NewTemplateVoicer()
	fixtures := map[voiceBucket]Forecast{
		bucketStorm:      bankForecast("Thunderstorm", 25, true),
		bucketSnow:       bankForecast("Snow", -2, true),
		bucketRain:       bankForecast("Rain", 20, true),
		bucketDrizzle:    bankForecast("Drizzle", 18, true),
		bucketFog:        bankForecast("Fog", 12, true),
		bucketHot:        bankForecast("Clear", 41, true),
		bucketCold:       bankForecast("Clear", -8, true),
		bucketOvercast:   bankForecast("Overcast", 20, true),
		bucketPartly:     bankForecast("Partly cloudy", 22, true),
		bucketClearDay:   bankForecast("Clear", 22, true),
		bucketClearNight: bankForecast("Clear", 22, false),
	}
	windy := bankForecast("Clear", 20, true)
	windy.Current.WindGustKph = 60
	fixtures[bucketWind] = windy

	levels := []VoiceLevel{LevelProper, LevelSassy, LevelSalty, LevelFeral}
	for bucket, f := range fixtures {
		for _, level := range levels {
			got, err := v.Speak(context.Background(), f, VoiceOpts{Level: level})
			if err != nil {
				t.Fatalf("%s/%s: %v", bucket, level, err)
			}
			if got.Line == "" || got.Briefing == "" {
				t.Errorf("%s/%s: empty output %+v", bucket, level, got)
			}
			if strings.Contains(got.Line, "{") || strings.Contains(got.Briefing, "{") {
				t.Errorf("%s/%s: unrendered placeholder in %+v", bucket, level, got)
			}
		}
	}
}

// TestTemplateVoicerUnits renders Fahrenheit when imperial is requested.
func TestTemplateVoicerUnits(t *testing.T) {
	t.Parallel()
	v := NewTemplateVoicer()
	f := bankForecast("Clear", 41, true)
	got, err := v.Speak(context.Background(), f, VoiceOpts{Level: LevelProper, Imperial: true})
	if err != nil {
		t.Fatalf("Speak: %v", err)
	}
	if !strings.Contains(got.Line+got.Briefing, "106°") {
		t.Errorf("imperial output missing 106°: %+v", got)
	}
}

// TestTemplateVoicerDeterministic returns the same pick for the same day.
func TestTemplateVoicerDeterministic(t *testing.T) {
	t.Parallel()
	v := NewTemplateVoicer()
	f := bankForecast("Rain", 20, true)
	a, err := v.Speak(context.Background(), f, VoiceOpts{Level: LevelSassy})
	if err != nil {
		t.Fatalf("first: %v", err)
	}
	b, err := v.Speak(context.Background(), f, VoiceOpts{Level: LevelSassy})
	if err != nil {
		t.Fatalf("second: %v", err)
	}
	if a.Line != b.Line || a.Briefing != b.Briefing {
		t.Errorf("outputs differ for identical input: %q vs %q", a.Line, b.Line)
	}
}

// TestFallbackVoicer uses the backup when the primary fails.
func TestFallbackVoicer(t *testing.T) {
	t.Parallel()
	boom := VoicerFunc(func(ctx context.Context, f Forecast, opts VoiceOpts) (Voice, error) {
		return Voice{}, errors.New("boom")
	})
	ok := VoicerFunc(func(ctx context.Context, f Forecast, opts VoiceOpts) (Voice, error) {
		return Voice{Line: "backup"}, nil
	})
	got, err := NewFallbackVoicer(boom, ok).Speak(context.Background(), sampleForecast(), VoiceOpts{})
	if err != nil {
		t.Fatalf("Speak: %v", err)
	}
	if got.Line != "backup" {
		t.Errorf("line = %q, want backup", got.Line)
	}
	// The primary answers when healthy.
	got, err = NewFallbackVoicer(ok, boom).Speak(context.Background(), sampleForecast(), VoiceOpts{})
	if err != nil || got.Line != "backup" {
		t.Errorf("healthy primary: got %q err %v", got.Line, err)
	}
}

// TestForecastContext reports the shape of the week from daily highs and
// precipitation probability, in priority order.
func TestForecastContext(t *testing.T) {
	t.Parallel()
	tests := []struct {
		WantResult string
		Daily      []DailyPoint
	}{{ // Test 0: Three-day heat streak wins first.
		Daily: []DailyPoint{
			{HighC: 34}, {HighC: 33}, {HighC: 32}, {HighC: 20},
		},
		WantResult: "That's 3 straight in the heat.",
	}, { // Test 1: Today is the strict week peak.
		Daily: []DailyPoint{
			{HighC: 28}, {HighC: 24}, {HighC: 22}, {HighC: 20},
		},
		WantResult: "Today is the hottest of the week.",
	}, { // Test 2: Cooling trend when no peak or streak.
		Daily: []DailyPoint{
			{HighC: 24}, {HighC: 20},
		},
		WantResult: "Cooler tomorrow.",
	}, { // Test 3: Wet stretch over the next five days.
		Daily: []DailyPoint{
			{HighC: 22, PrecipProb: 60}, {HighC: 22, PrecipProb: 55},
			{HighC: 22, PrecipProb: 70}, {HighC: 22, PrecipProb: 10},
			{HighC: 22, PrecipProb: 20},
		},
		WantResult: "A wet stretch ahead, 3 of the next five.",
	}, { // Test 4: Mild, unremarkable week returns nothing.
		Daily: []DailyPoint{
			{HighC: 22, PrecipProb: 10}, {HighC: 23, PrecipProb: 10},
			{HighC: 22, PrecipProb: 20}, {HighC: 21, PrecipProb: 15},
		},
		WantResult: "",
	}}
	for testNum, test := range tests {
		t.Run(fmt.Sprintf("test %d", testNum), func(t *testing.T) {
			t.Parallel()
			got := forecastContext(Forecast{Daily: test.Daily}, false)
			if diff := cmp.Diff(test.WantResult, got); diff != "" {
				t.Errorf("mismatch (-want +got):\n%s", diff)
			}
		})
	}
}

// TestEventLine reads the weather at the next calendar event, matching the
// closest hourly point and leading with the hazard or extreme.
func TestEventLine(t *testing.T) {
	t.Parallel()
	base := int64(1_600_000_000)
	hourly := []HourlyPoint{
		{Time: time.Unix(base, 0), Condition: "Clear", TempC: 34, ApparentTempC: 35},
		{Time: time.Unix(base+3600, 0), Condition: "Light rain", TempC: 20, ApparentTempC: 21},
		{Time: time.Unix(base+7200, 0), Condition: "Clear", TempC: 24, ApparentTempC: 24},
	}
	tests := []struct {
		WantResult string
		Opts       VoiceOpts
	}{{ // Test 0: Matches a hot hour.
		Opts: VoiceOpts{
			EventTitle: "Pickup", EventWhen: "3 PM", EventEpoch: base + 300,
		},
		WantResult: "Pickup at 3 PM: hot, 35°, water for it.",
	}, { // Test 1: Matches a rainy hour.
		Opts: VoiceOpts{
			EventTitle: "Walk", EventWhen: "4 PM", EventEpoch: base + 3600,
		},
		WantResult: "Walk at 4 PM: wet, bring cover.",
	}, { // Test 2: Empty title yields nothing.
		Opts: VoiceOpts{
			EventTitle: "", EventWhen: "3 PM", EventEpoch: base + 300,
		},
		WantResult: "",
	}, { // Test 3: Epoch far from any hour yields nothing.
		Opts: VoiceOpts{
			EventTitle: "Late", EventWhen: "9 PM", EventEpoch: base + 100000,
		},
		WantResult: "",
	}}
	for testNum, test := range tests {
		t.Run(fmt.Sprintf("test %d", testNum), func(t *testing.T) {
			t.Parallel()
			f := Forecast{Hourly: hourly}
			got := eventLine(f, test.Opts)
			if diff := cmp.Diff(test.WantResult, got); diff != "" {
				t.Errorf("mismatch (-want +got):\n%s", diff)
			}
		})
	}
}

// TestCondPhrase turns condition names into sentence-ready phrases.
func TestCondPhrase(t *testing.T) {
	t.Parallel()
	tests := []struct {
		In   string
		Want string
	}{
		{In: "Clear", Want: "clear skies"},                 // Test 0: Clear gains skies.
		{In: "Mainly clear", Want: "mainly clear skies"},   // Test 1: Mainly clear.
		{In: "Partly cloudy", Want: "partly cloudy skies"}, // Test 2: Cloudy.
		{In: "Overcast", Want: "overcast skies"},           // Test 3: Overcast.
		{In: "Light rain", Want: "light rain"},             // Test 4: Rain passes through.
		{In: "Thunderstorm", Want: "thunderstorms"},        // Test 5: Storms pluralize.
		{In: "Fog", Want: "fog"},                           // Test 6: Fog passes through.
	}
	for testNum, test := range tests {
		t.Run(fmt.Sprintf("test %d", testNum), func(t *testing.T) {
			t.Parallel()
			if got := condPhrase(test.In); got != test.Want {
				t.Errorf("condPhrase(%q) = %q, want %q", test.In, got, test.Want)
			}
		})
	}
}
