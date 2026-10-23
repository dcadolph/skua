package skua

import (
	"fmt"
	"strings"
)

// Occasion is a dated party pack that takes over the skua's voice, like a
// bachelorette weekend. The empty Occasion means no pack is active.
type Occasion string

const (
	// OccasionNone leaves the everyday voice in charge.
	OccasionNone Occasion = ""
	// OccasionBachelorette is the bride squad's weekend.
	OccasionBachelorette Occasion = "bachelorette"
	// OccasionBachelor is the groom's crew's weekend.
	OccasionBachelor Occasion = "bachelor"
)

// ParseOccasion normalizes a requested occasion, returning OccasionNone for
// empty or unrecognized input.
func ParseOccasion(s string) Occasion {
	o := Occasion(strings.ToLower(strings.TrimSpace(s)))
	if _, ok := partyPacks[o]; ok {
		return o
	}
	return OccasionNone
}

// Heat is how filthy an occasion pack talks, from cheeky innuendo up to
// nothing held back.
type Heat string

const (
	// HeatDirty is cheeky innuendo.
	HeatDirty Heat = "dirty"
	// HeatKinky is openly suggestive.
	HeatKinky Heat = "kinky"
	// HeatRaunchy is explicit and profane.
	HeatRaunchy Heat = "raunchy"
	// HeatSlut is everything at once, no brakes.
	HeatSlut Heat = "slut"
)

// DefaultHeat is used when no heat is requested or the request is unknown.
const DefaultHeat = HeatDirty

// ParseHeat normalizes a requested heat, falling back to DefaultHeat.
func ParseHeat(s string) Heat {
	h := Heat(strings.ToLower(strings.TrimSpace(s)))
	switch h {
	case HeatDirty, HeatKinky, HeatRaunchy, HeatSlut:
		return h
	default:
		return DefaultHeat
	}
}

// partyMood is the coarse sky a party line reacts to. It folds the twelve
// voice buckets into the seven situations a party actually cares about.
type partyMood string

const (
	moodSunny  partyMood = "sunny"
	moodHot    partyMood = "hot"
	moodNight  partyMood = "night"
	moodGloomy partyMood = "gloomy"
	moodWet    partyMood = "wet"
	moodCold   partyMood = "cold"
	moodWind   partyMood = "wind"
)

// partyMoodFor folds a forecast into a party mood.
func partyMoodFor(f Forecast) partyMood {
	switch bucketFor(f) {
	case bucketStorm, bucketSnow, bucketRain, bucketDrizzle:
		return moodWet
	case bucketFog, bucketOvercast:
		return moodGloomy
	case bucketHot:
		return moodHot
	case bucketCold:
		return moodCold
	case bucketWind:
		return moodWind
	case bucketClearNight:
		return moodNight
	}
	if !f.Current.IsDay {
		return moodNight
	}
	return moodSunny
}

// partyPhase is the stretch of the party day, read from the local hour.
type partyPhase string

const (
	phaseMorning   partyPhase = "morning"
	phaseAfternoon partyPhase = "afternoon"
	phaseEvening   partyPhase = "evening"
	phaseLate      partyPhase = "late"
)

// partyPhaseFor maps a local hour onto a party phase. Out-of-range hours read
// as late night, which is when nobody knows what time it is anyway.
func partyPhaseFor(hour int) partyPhase {
	switch {
	case hour >= 5 && hour < 11:
		return phaseMorning
	case hour >= 11 && hour < 17:
		return phaseAfternoon
	case hour >= 17 && hour < 21:
		return phaseEvening
	default:
		return phaseLate
	}
}

// partyPack is one occasion's full bank of lines.
type partyPack struct {
	// lines is the headline quip per sky mood per heat.
	lines map[partyMood]map[Heat][]string
	// openers leads the briefing per phase of the day per heat.
	openers map[partyPhase]map[Heat][]string
	// advice closes the briefing with the useful part, per mood per heat.
	advice map[partyMood]map[Heat]string
}

// speakParty renders the occasion's line and briefing for f. It reports false
// when opts carries no known occasion, so the caller falls back to the
// everyday voice.
func speakParty(f Forecast, opts VoiceOpts) (Voice, bool) {
	pack, ok := partyPacks[opts.Occasion]
	if !ok {
		return Voice{}, false
	}
	heat := ParseHeat(string(opts.Heat))
	mood := partyMoodFor(f)
	phase := partyPhaseFor(opts.LocalHour)
	vals := voiceVals(f, opts.Imperial)

	// Seed by the local hour too, so the quip turns over as the party moves.
	seed := fmt.Sprintf("%s|%s|%s|%s|%d|%.1f,%.1f", opts.Occasion, heat, mood,
		f.Current.Time.Format("2006-01-02"), opts.LocalHour, f.Location.Lat, f.Location.Lon)
	line := renderVoice(pickLine(pack.lines[mood][heat], seed), vals)

	var parts []string
	if opener := pickLine(pack.openers[phase][heat], seed+"|open"); opener != "" {
		parts = append(parts, opener)
	}
	if ev := eventLine(f, opts); ev != "" {
		parts = append(parts, ev)
	}
	parts = append(parts, capitalize(renderVoice("{cond} today, {low} to {high}.", vals)))
	if len(f.Daily) > 0 && f.Daily[0].PrecipProb >= 20 {
		parts = append(parts, renderVoice("{rain} chance of rain.", vals))
	}
	if advice := pack.advice[mood][heat]; advice != "" {
		parts = append(parts, advice)
	}
	return Voice{Line: capitalize(line), Briefing: strings.Join(parts, " ")}, true
}
