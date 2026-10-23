package skua

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/anthropics/anthropic-sdk-go/option"
)

// anthropicVoiceBody is a canned Anthropic Messages API response whose text is a
// JSON voice object.
const anthropicVoiceBody = `{
  "id": "msg_1",
  "type": "message",
  "role": "assistant",
  "model": "claude-haiku-4-5",
  "content": [{"type": "text", "text": "{\"line\":\"Rain by five. Cancel the run.\",\"briefing\":\"Overcast now and wet by evening. Move outdoor plans earlier and keep a jacket handy.\"}"}],
  "stop_reason": "end_turn",
  "stop_sequence": null,
  "usage": {"input_tokens": 30, "output_tokens": 40}
}`

// sampleForecast is a small forecast fixture for voice tests.
func sampleForecast() Forecast {
	return Forecast{
		Source:   "test",
		Location: Location{Lat: 30.27, Lon: -97.74},
		Current:  Current{TempC: 26, ApparentTempC: 28, Condition: "Overcast", WindKph: 12, Humidity: 70, IsDay: true},
		Daily:    []DailyPoint{{HighC: 31, LowC: 23, Condition: "Rain", PrecipProb: 60}},
	}
}

// TestClaudeVoicerSpeak verifies a canned Claude response is parsed into a Voice.
func TestClaudeVoicerSpeak(t *testing.T) {
	t.Parallel()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(anthropicVoiceBody))
	}))
	defer srv.Close()

	v := NewClaudeVoicer("test-key", option.WithBaseURL(srv.URL))
	got, err := v.Speak(context.Background(), sampleForecast(), VoiceOpts{Level: LevelProper})
	if err != nil {
		t.Fatalf("Speak: %v", err)
	}
	if !strings.Contains(got.Line, "Cancel the run") {
		t.Errorf("line = %q, want it to mention the run", got.Line)
	}
	if got.Briefing == "" {
		t.Error("briefing is empty")
	}
}

// TestParseVoice covers clean JSON, JSON with surrounding prose, the plain-text
// fallback, and the empty case.
func TestParseVoice(t *testing.T) {
	t.Parallel()
	tests := []struct {
		In       string
		WantLine string
		Want     error
	}{
		{In: `{"line":"a","briefing":"b"}`, WantLine: "a"},                                 // Test 0: Clean JSON.
		{In: "Sure!\n{\"line\":\"a\",\"briefing\":\"b\"}\nHope that helps", WantLine: "a"}, // Test 1: JSON with prose.
		{In: "just a line", WantLine: "just a line"},                                       // Test 2: Plain-text fallback.
		{In: "   ", Want: ErrVoice},                                                        // Test 3: Empty.
	}
	for testNum, test := range tests {
		t.Run(fmt.Sprintf("test %d", testNum), func(t *testing.T) {
			t.Parallel()
			got, err := parseVoice(test.In)
			if !errors.Is(err, test.Want) {
				t.Fatalf("err = %v, want %v", err, test.Want)
			}
			if test.Want == nil && got.Line != test.WantLine {
				t.Errorf("line = %q, want %q", got.Line, test.WantLine)
			}
		})
	}
}

// TestParseVoiceLevel covers each level plus casing, trimming, and fallback.
func TestParseVoiceLevel(t *testing.T) {
	t.Parallel()
	tests := []struct {
		In   string
		Want VoiceLevel
	}{
		{In: "proper", Want: LevelProper},      // Test 0: Exact.
		{In: "sassy", Want: LevelSassy},        // Test 1: Exact.
		{In: "SALTY", Want: LevelSalty},        // Test 2: Uppercase.
		{In: "  feral ", Want: LevelFeral},     // Test 3: Trimmed.
		{In: "", Want: DefaultVoiceLevel},      // Test 4: Empty falls back.
		{In: "spicy", Want: DefaultVoiceLevel}, // Test 5: Unknown falls back.
	}
	for testNum, test := range tests {
		t.Run(fmt.Sprintf("test %d", testNum), func(t *testing.T) {
			t.Parallel()
			if got := ParseVoiceLevel(test.In); got != test.Want {
				t.Errorf("ParseVoiceLevel(%q) = %q, want %q", test.In, got, test.Want)
			}
		})
	}
}

// TestVoiceSystemPrompt confirms each level yields its own tone and an unknown
// level falls back to the default.
func TestVoiceSystemPrompt(t *testing.T) {
	t.Parallel()
	tests := []struct {
		Level   VoiceLevel
		WantHas string
	}{
		{Level: LevelProper, WantHas: "professional"},         // Test 0: Proper tone.
		{Level: LevelSassy, WantHas: "snarky"},                // Test 1: Sassy tone.
		{Level: LevelSalty, WantHas: "profane"},               // Test 2: Salty tone.
		{Level: LevelFeral, WantHas: "raunchy"},               // Test 3: Feral tone.
		{Level: VoiceLevel("bogus"), WantHas: "professional"}, // Test 4: Unknown falls back to proper.
	}
	for testNum, test := range tests {
		t.Run(fmt.Sprintf("test %d", testNum), func(t *testing.T) {
			t.Parallel()
			got := voiceSystemPrompt(test.Level)
			if !strings.Contains(got, voiceBaseContract) {
				t.Error("system prompt missing the base contract")
			}
			if !strings.Contains(strings.ToLower(got), test.WantHas) {
				t.Errorf("level %q prompt missing %q", test.Level, test.WantHas)
			}
		})
	}
}
