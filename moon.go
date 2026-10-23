package skua

import (
	"math"
	"time"
)

// Moon describes the lunar phase at a moment.
type Moon struct {
	// Phase is the position in the synodic cycle, 0 at new moon through 1 back
	// to new.
	Phase float64 `json:"phase"`
	// Illumination is the sunlit fraction of the visible disk, 0 to 1.
	Illumination float64 `json:"illumination"`
	// Name is the common phase name.
	Name string `json:"name"`
	// Index is the phase octant, 0 new moon through 7 waning crescent.
	Index int `json:"index"`
}

// synodicDays is the mean length of a lunar cycle in days.
const synodicDays = 29.530588853

// lunarEpoch is a reference new moon: January 6, 2000 at 18:14 UTC.
var lunarEpoch = time.Date(2000, 1, 6, 18, 14, 0, 0, time.UTC)

// moonNames is the octant naming, new moon first.
var moonNames = [8]string{
	"New moon", "Waxing crescent", "First quarter", "Waxing gibbous",
	"Full moon", "Waning gibbous", "Last quarter", "Waning crescent",
}

// moonAt computes the lunar phase at t from the mean synodic cycle, accurate to
// within several hours, which is plenty for a phase readout.
func moonAt(t time.Time) Moon {
	days := t.Sub(lunarEpoch).Hours() / 24
	phase := math.Mod(days/synodicDays, 1)
	if phase < 0 {
		phase++
	}
	idx := int(math.Floor(phase*8+0.5)) % 8
	return Moon{
		Phase:        phase,
		Illumination: (1 - math.Cos(2*math.Pi*phase)) / 2,
		Name:         moonNames[idx],
		Index:        idx,
	}
}
