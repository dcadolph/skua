package skua

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/anthropics/anthropic-sdk-go"
	"github.com/anthropics/anthropic-sdk-go/option"
)

// VoiceLevel is the register the skua speaks in. Dry is the house voice; the
// rest run from clean and professional to unhinged and raunchy.
type VoiceLevel string

const (
	// LevelDry is understated and unbothered, the default register.
	LevelDry VoiceLevel = "dry"
	// LevelProper is clean, professional, and precise.
	LevelProper VoiceLevel = "proper"
	// LevelSassy is snarky and teasing, with no profanity.
	LevelSassy VoiceLevel = "sassy"
	// LevelSalty is blunt and profane.
	LevelSalty VoiceLevel = "salty"
	// LevelFeral is unhinged, raunchy, and unfiltered.
	LevelFeral VoiceLevel = "feral"
)

// DefaultVoiceLevel is used when no level is requested or the request is unknown.
const DefaultVoiceLevel = LevelDry

// ParseVoiceLevel normalizes a requested level, falling back to the default for
// empty or unrecognized input.
func ParseVoiceLevel(s string) VoiceLevel {
	level := VoiceLevel(strings.ToLower(strings.TrimSpace(s)))
	switch level {
	case LevelDry, LevelProper, LevelSassy, LevelSalty, LevelFeral:
		return level
	default:
		return DefaultVoiceLevel
	}
}

// voiceBaseContract is the shared persona and output contract for every level.
const voiceBaseContract = `You are Skua, the voice of a weather app: a stout, storm-riding seabird that reads a forecast and reacts to it. Stay specific to the actual conditions, never generic, and always land a real, useful recommendation under the attitude. American English. No emojis. Do not use dashes or middot separators.

Respond with ONLY a JSON object, no preamble, of this form:
{"line": "...", "briefing": "..."}
line: one punchy sentence under 140 characters.
briefing: two or three plain sentences saying what the day holds and what to do about it.`

// voiceToneByLevel maps each level to the tone directive layered on the base
// contract. The runtime model bounds the actual output regardless of tone.
var voiceToneByLevel = map[VoiceLevel]string{
	LevelProper: `Tone: clean, professional, and precise, like a sharp meteorologist who respects your time. No slang, no profanity, no jokes at anyone's expense. Clear, confident guidance.`,
	LevelSassy:  `Tone: dry, snarky, and teasing. Crack wise about the weather and rib the reader lightly. Plenty of attitude and wit, but keep it clean with no profanity.`,
	LevelSalty:  `Tone: blunt and profane, like a salty sea captain who has had enough. Curse freely when the weather earns it. Crude and funny, but keep the swearing pointed at the weather, and still deliver genuinely useful advice. No sexual content.`,
	LevelFeral:  `Tone: unhinged, raunchy, and completely unfiltered. Swear hard and lean into crude, absurd, sexually suggestive humor about the sky, the storm, and the weather itself. Be lewd, rude, and ridiculous. Two rules only: keep the raunch aimed at the weather rather than at the reader, and bury a genuinely useful recommendation somewhere in the chaos.`,
}

// voiceSystemPrompt returns the full system prompt for a level, combining the
// shared contract with the level's tone.
func voiceSystemPrompt(level VoiceLevel) string {
	tone, ok := voiceToneByLevel[level]
	if !ok {
		tone = voiceToneByLevel[LevelProper]
	}
	return voiceBaseContract + "\n\n" + tone
}

// voiceModel is the model used for the voice. Haiku is cheap and fast, and the
// per-line cost is a fraction of a cent.
const voiceModel = anthropic.ModelClaudeHaiku4_5_20251001

// voiceMaxTokens caps the generated line and briefing.
const voiceMaxTokens = 400

// Voice is the generated personality output for a forecast.
type Voice struct {
	// Line is the short, sharp, in-character remark.
	Line string `json:"line"`
	// Briefing is the longer paragraph fusing the day into plain guidance.
	Briefing string `json:"briefing"`
}

// VoiceOpts shapes one spoken response.
type VoiceOpts struct {
	// Level is the maturity and profanity level.
	Level VoiceLevel
	// EventTitle is the next calendar event's title, empty when there is none.
	EventTitle string
	// EventWhen is the event start pre-formatted in local time, like "3 PM".
	EventWhen string
	// EventEpoch is the event start as Unix seconds, zero when there is no event.
	EventEpoch int64
	// Imperial reports whether spoken numbers use Fahrenheit and miles.
	Imperial bool
	// Occasion is the active party pack, OccasionNone for the everyday voice.
	Occasion Occasion
	// Heat is how filthy the occasion pack talks.
	Heat Heat
	// LocalHour is the listener's local hour of day, zero to 23, used to pick
	// the occasion's time-of-day opener.
	LocalHour int
}

// Voicer turns a forecast into the skua's voice.
type Voicer interface {
	// Speak returns the skua's take on the forecast.
	Speak(ctx context.Context, f Forecast, opts VoiceOpts) (Voice, error)
}

// VoicerFunc adapts an ordinary function to a Voicer.
type VoicerFunc func(ctx context.Context, f Forecast, opts VoiceOpts) (Voice, error)

// Speak calls fn.
func (fn VoicerFunc) Speak(ctx context.Context, f Forecast, opts VoiceOpts) (Voice, error) {
	return fn(ctx, f, opts)
}

// FallbackVoicer speaks with a primary voicer and falls back to a backup when
// the primary fails, so the voice never goes silent.
type FallbackVoicer struct {
	// primary is tried first.
	primary Voicer
	// backup answers when the primary errors.
	backup Voicer
}

// NewFallbackVoicer chains primary and backup.
func NewFallbackVoicer(primary, backup Voicer) *FallbackVoicer {
	if primary == nil || backup == nil {
		panic("NewFallbackVoicer: primary and backup Voicers required")
	}
	return &FallbackVoicer{primary: primary, backup: backup}
}

// Speak tries the primary voicer, then the backup.
func (v *FallbackVoicer) Speak(ctx context.Context, f Forecast, opts VoiceOpts) (Voice, error) {
	out, err := v.primary.Speak(ctx, f, opts)
	if err == nil {
		return out, nil
	}
	return v.backup.Speak(ctx, f, opts)
}

// ClaudeVoicer is a Voicer backed by Anthropic's Claude models.
type ClaudeVoicer struct {
	// client is the Anthropic API client.
	client anthropic.Client
}

// NewClaudeVoicer builds a ClaudeVoicer from an API key. Extra request options
// are passed through, mainly to override the base URL in tests.
func NewClaudeVoicer(apiKey string, opts ...option.RequestOption) *ClaudeVoicer {
	reqOpts := append([]option.RequestOption{option.WithAPIKey(apiKey)}, opts...)
	return &ClaudeVoicer{client: anthropic.NewClient(reqOpts...)}
}

// Speak asks Claude for the skua's line and briefing for f.
func (v *ClaudeVoicer) Speak(ctx context.Context, f Forecast, opts VoiceOpts) (Voice, error) {
	resp, err := v.client.Messages.New(ctx, anthropic.MessageNewParams{
		Model:     voiceModel,
		MaxTokens: voiceMaxTokens,
		System:    []anthropic.TextBlockParam{{Text: voiceSystemPrompt(opts.Level)}},
		Messages: []anthropic.MessageParam{
			anthropic.NewUserMessage(anthropic.NewTextBlock(voicePrompt(f, opts))),
		},
	})
	if err != nil {
		return Voice{}, fmt.Errorf("%w: %w", ErrVoice, err)
	}
	var text strings.Builder
	for _, block := range resp.Content {
		if tb, ok := block.AsAny().(anthropic.TextBlock); ok {
			text.WriteString(tb.Text)
		}
	}
	return parseVoice(text.String())
}

// voicePrompt renders a compact, model-friendly summary of the forecast in the
// unit system the listener uses.
func voicePrompt(f Forecast, opts VoiceOpts) string {
	deg, spd, degUnit := func(c float64) float64 { return c }, func(k float64) float64 { return k }, "C"
	if opts.Imperial {
		deg = func(c float64) float64 { return c*1.8 + 32 }
		spd = func(k float64) float64 { return k * 0.621371 }
		degUnit = "F"
	}
	c := f.Current
	var b strings.Builder
	fmt.Fprintf(&b, "Speak in %s degrees. Now: %.0f%s (feels %.0f%s), %s, wind %.0f, humidity %d%%.\n",
		map[bool]string{true: "Fahrenheit", false: "Celsius"}[opts.Imperial],
		deg(c.TempC), degUnit, deg(c.ApparentTempC), degUnit, c.Condition, spd(c.WindKph), c.Humidity)
	if len(f.Hourly) > 0 {
		b.WriteString("Next hours:")
		for i, h := range f.Hourly {
			if i >= 6 {
				break
			}
			fmt.Fprintf(&b, " %s %.0f %d%% rain;", h.Time.Format("15h"), deg(h.TempC), h.PrecipProb)
		}
		b.WriteString("\n")
	}
	if len(f.Daily) > 0 {
		d := f.Daily[0]
		fmt.Fprintf(&b, "Today: high %.0f, low %.0f, %s, rain %d%%.\n",
			deg(d.HighC), deg(d.LowC), d.Condition, d.PrecipProb)
	}
	return b.String()
}

// parseVoice extracts a Voice from the model's text. It tolerates surrounding
// prose by pulling out the JSON object, and falls back to using the whole reply
// as the line when there is no parseable object.
func parseVoice(s string) (Voice, error) {
	s = strings.TrimSpace(s)
	if start, end := strings.Index(s, "{"), strings.LastIndex(s, "}"); start >= 0 && end > start {
		var v Voice
		if err := json.Unmarshal([]byte(s[start:end+1]), &v); err == nil && v.Line != "" {
			return v, nil
		}
	}
	if s == "" {
		return Voice{}, fmt.Errorf("%w: empty response", ErrVoice)
	}
	return Voice{Line: s}, nil
}
