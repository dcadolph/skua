package skua

import (
	"context"
	"fmt"
	"slices"
	"strings"
	"testing"

	"github.com/google/go-cmp/cmp"
)

// allHeats lists every heat in dial order.
var allHeats = []Heat{HeatDirty, HeatKinky, HeatRaunchy, HeatSlut} //nolint:gochecknoglobals // Not modified, simplifies testing.

// allMoods lists every party mood.
var allMoods = []partyMood{moodSunny, moodHot, moodNight, moodGloomy, moodWet, moodCold, moodWind} //nolint:gochecknoglobals // Not modified, simplifies testing.

// allPhases lists every party phase.
var allPhases = []partyPhase{phaseMorning, phaseAfternoon, phaseEvening, phaseLate} //nolint:gochecknoglobals // Not modified, simplifies testing.

func TestParseOccasion(t *testing.T) {
	t.Parallel()
	tests := []struct {
		WantResult Occasion
		In         string
	}{{ // Test 0: Known pack.
		In: "bachelorette", WantResult: OccasionBachelorette,
	}, { // Test 1: Case and spacing are normalized.
		In: "  Bachelor ", WantResult: OccasionBachelor,
	}, { // Test 2: Empty is none.
		In: "", WantResult: OccasionNone,
	}, { // Test 3: Unknown is none.
		In: "wedding", WantResult: OccasionNone,
	}}
	for testNum, test := range tests {
		t.Run(fmt.Sprintf("test %d", testNum), func(t *testing.T) {
			t.Parallel()
			if diff := cmp.Diff(test.WantResult, ParseOccasion(test.In)); diff != "" {
				t.Errorf("mismatch (-want +got):\n%s", diff)
			}
		})
	}
}

func TestParseHeat(t *testing.T) {
	t.Parallel()
	tests := []struct {
		WantResult Heat
		In         string
	}{{ // Test 0: Top of the dial.
		In: "slut", WantResult: HeatSlut,
	}, { // Test 1: Case is normalized.
		In: "RAUNCHY", WantResult: HeatRaunchy,
	}, { // Test 2: Empty falls back to the default.
		In: "", WantResult: DefaultHeat,
	}, { // Test 3: Unknown falls back to the default.
		In: "spicy", WantResult: DefaultHeat,
	}}
	for testNum, test := range tests {
		t.Run(fmt.Sprintf("test %d", testNum), func(t *testing.T) {
			t.Parallel()
			if diff := cmp.Diff(test.WantResult, ParseHeat(test.In)); diff != "" {
				t.Errorf("mismatch (-want +got):\n%s", diff)
			}
		})
	}
}

func TestPartyPhaseFor(t *testing.T) {
	t.Parallel()
	tests := []struct {
		WantResult partyPhase
		In         int
	}{{ // Test 0: Dawn starts the morning.
		In: 5, WantResult: phaseMorning,
	}, { // Test 1: Late morning is still morning.
		In: 10, WantResult: phaseMorning,
	}, { // Test 2: Eleven starts the afternoon.
		In: 11, WantResult: phaseAfternoon,
	}, { // Test 3: Five PM starts the evening.
		In: 17, WantResult: phaseEvening,
	}, { // Test 4: Nine PM is late.
		In: 21, WantResult: phaseLate,
	}, { // Test 5: Two AM is late.
		In: 2, WantResult: phaseLate,
	}, { // Test 6: An out-of-range hour reads as late.
		In: 99, WantResult: phaseLate,
	}}
	for testNum, test := range tests {
		t.Run(fmt.Sprintf("test %d", testNum), func(t *testing.T) {
			t.Parallel()
			if diff := cmp.Diff(test.WantResult, partyPhaseFor(test.In)); diff != "" {
				t.Errorf("mismatch (-want +got):\n%s", diff)
			}
		})
	}
}

func TestPartyMoodFor(t *testing.T) {
	t.Parallel()
	tests := []struct {
		WantResult partyMood
		Condition  string
		Feels      float64
		IsDay      bool
	}{{ // Test 0: Clear day is sunny.
		Condition: "Clear", Feels: 22, IsDay: true, WantResult: moodSunny,
	}, { // Test 1: Partly cloudy at night reads as night.
		Condition: "Partly cloudy", Feels: 15, IsDay: false, WantResult: moodNight,
	}, { // Test 2: Clear night is night.
		Condition: "Clear", Feels: 15, IsDay: false, WantResult: moodNight,
	}, { // Test 3: Fog is gloomy.
		Condition: "Fog", Feels: 15, IsDay: true, WantResult: moodGloomy,
	}, { // Test 4: A storm is wet.
		Condition: "Thunderstorm", Feels: 25, IsDay: true, WantResult: moodWet,
	}, { // Test 5: Extreme heat is hot.
		Condition: "Clear", Feels: 38, IsDay: true, WantResult: moodHot,
	}, { // Test 6: Freezing is cold.
		Condition: "Clear", Feels: -3, IsDay: true, WantResult: moodCold,
	}}
	for testNum, test := range tests {
		t.Run(fmt.Sprintf("test %d", testNum), func(t *testing.T) {
			t.Parallel()
			got := partyMoodFor(bankForecast(test.Condition, test.Feels, test.IsDay))
			if diff := cmp.Diff(test.WantResult, got); diff != "" {
				t.Errorf("mismatch (-want +got):\n%s", diff)
			}
		})
	}
}

// TestPartyPacksComplete holds every pack to full coverage, so no mood, phase,
// or heat can ever land on an empty line.
func TestPartyPacksComplete(t *testing.T) {
	t.Parallel()
	known := []string{"{temp}", "{feels}", "{high}", "{low}", "{wind}", "{gust}", "{rain}", "{cond}"}
	check := func(t *testing.T, where, s string) {
		t.Helper()
		if strings.TrimSpace(s) == "" {
			t.Errorf("%s: empty", where)
		}
		if strings.ContainsAny(s, "—–·") {
			t.Errorf("%s: dash or middot in %q", where, s)
		}
		rest := s
		for _, k := range known {
			rest = strings.ReplaceAll(rest, k, "")
		}
		if strings.ContainsAny(rest, "{}") {
			t.Errorf("%s: unknown placeholder in %q", where, s)
		}
	}
	for occ, pack := range partyPacks {
		for _, heat := range allHeats {
			for _, mood := range allMoods {
				lines := pack.lines[mood][heat]
				if len(lines) == 0 {
					t.Errorf("%s/%s/%s: no lines", occ, mood, heat)
				}
				for i, l := range lines {
					check(t, fmt.Sprintf("%s/%s/%s line %d", occ, mood, heat, i), l)
				}
				check(t, fmt.Sprintf("%s/%s/%s advice", occ, mood, heat), pack.advice[mood][heat])
			}
			for _, phase := range allPhases {
				openers := pack.openers[phase][heat]
				if len(openers) == 0 {
					t.Errorf("%s/%s/%s: no openers", occ, phase, heat)
				}
				for i, o := range openers {
					check(t, fmt.Sprintf("%s/%s/%s opener %d", occ, phase, heat, i), o)
				}
			}
		}
	}
}

func TestTemplateVoicerParty(t *testing.T) {
	t.Parallel()
	tests := []struct {
		WantOpeners []string
		WantLines   []string
		Occasion    Occasion
		Heat        Heat
		Hour        int
	}{{ // Test 0: Bachelorette, slut heat, sunny afternoon.
		Occasion: OccasionBachelorette, Heat: HeatSlut, Hour: 14,
		WantLines:   bachelorettePack.lines[moodSunny][HeatSlut],
		WantOpeners: bachelorettePack.openers[phaseAfternoon][HeatSlut],
	}, { // Test 1: Bachelor, dirty heat, morning.
		Occasion: OccasionBachelor, Heat: HeatDirty, Hour: 8,
		WantLines:   bachelorPack.lines[moodSunny][HeatDirty],
		WantOpeners: bachelorPack.openers[phaseMorning][HeatDirty],
	}, { // Test 2: An unknown heat speaks at the default.
		Occasion: OccasionBachelorette, Heat: "nuclear", Hour: 23,
		WantLines:   bachelorettePack.lines[moodSunny][DefaultHeat],
		WantOpeners: bachelorettePack.openers[phaseLate][DefaultHeat],
	}}
	fc := bankForecast("Clear", 24, true)
	vals := voiceVals(fc, true)
	for testNum, test := range tests {
		t.Run(fmt.Sprintf("test %d", testNum), func(t *testing.T) {
			t.Parallel()
			got, err := NewTemplateVoicer().Speak(context.Background(), fc, VoiceOpts{
				Occasion: test.Occasion, Heat: test.Heat, LocalHour: test.Hour, Imperial: true,
			})
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			rendered := make([]string, 0, len(test.WantLines))
			for _, l := range test.WantLines {
				rendered = append(rendered, capitalize(renderVoice(l, vals)))
			}
			if !slices.Contains(rendered, got.Line) {
				t.Errorf("line %q not from the expected bank", got.Line)
			}
			if !slices.ContainsFunc(test.WantOpeners, func(o string) bool {
				return strings.HasPrefix(got.Briefing, o)
			}) {
				t.Errorf("briefing %q does not open with the expected phase", got.Briefing)
			}
		})
	}
}

func TestTemplateVoicerNoOccasion(t *testing.T) {
	t.Parallel()
	fc := bankForecast("Clear", 24, true)
	got, err := NewTemplateVoicer().Speak(context.Background(), fc, VoiceOpts{Level: LevelProper})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	vals := voiceVals(fc, false)
	rendered := make([]string, 0, 3)
	for _, l := range voiceLines[bucketClearDay][LevelProper] {
		rendered = append(rendered, capitalize(renderVoice(l, vals)))
	}
	if !slices.Contains(rendered, got.Line) {
		t.Errorf("line %q is not the everyday proper voice", got.Line)
	}
}
