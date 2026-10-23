package skua

import (
	"context"
	"fmt"
	"math"
	"sync"
	"time"
)

// CachingVoicer wraps a Voicer and reuses a recent line for similar weather,
// keeping the per-request cost of the AI voice near zero.
type CachingVoicer struct {
	// next is the wrapped voicer consulted on a cache miss.
	next Voicer
	// ttl is how long a cached voice stays fresh.
	ttl time.Duration
	// now returns the current time and is overridable in tests.
	now func() time.Time
	// mu guards entries.
	mu sync.RWMutex
	// entries holds cached voices by coarse-forecast key.
	entries map[string]voiceEntry
}

// voiceEntry is a stored voice with its expiry.
type voiceEntry struct {
	// voice is the cached result.
	voice Voice
	// expires is when the entry stops being fresh.
	expires time.Time
}

// CachingVoicerOption configures a CachingVoicer.
type CachingVoicerOption func(*CachingVoicer)

// NewCachingVoicer wraps next with an in-memory voice cache.
func NewCachingVoicer(next Voicer, opts ...CachingVoicerOption) *CachingVoicer {
	if next == nil {
		panic("NewCachingVoicer: next Voicer required")
	}
	c := &CachingVoicer{
		next:    next,
		ttl:     30 * time.Minute,
		now:     time.Now,
		entries: make(map[string]voiceEntry),
	}
	for _, opt := range opts {
		opt(c)
	}
	return c
}

// WithVoiceTTL sets how long a cached voice stays fresh.
func WithVoiceTTL(d time.Duration) CachingVoicerOption {
	return func(c *CachingVoicer) { c.ttl = d }
}

// Speak returns a cached voice when the weather is close enough, otherwise asks
// the wrapped voicer and caches the result. Errors are never cached. The level
// and unit system are part of the key so each combination caches independently.
func (c *CachingVoicer) Speak(ctx context.Context, f Forecast, opts VoiceOpts) (Voice, error) {
	key := fmt.Sprintf("%s|%t|%s", opts.Level, opts.Imperial, voiceKey(f))

	c.mu.RLock()
	entry, ok := c.entries[key]
	c.mu.RUnlock()
	if ok && c.now().Before(entry.expires) {
		return entry.voice, nil
	}

	v, err := c.next.Speak(ctx, f, opts)
	if err != nil {
		return Voice{}, err
	}

	c.mu.Lock()
	c.entries[key] = voiceEntry{voice: v, expires: c.now().Add(c.ttl)}
	c.mu.Unlock()
	return v, nil
}

// voiceKey builds a coarse signature of the forecast so similar weather shares a
// line: rounded location, temperature bucket, condition, precipitation bucket,
// and day or night.
func voiceKey(f Forecast) string {
	c := f.Current
	tempBucket := int(math.Round(c.TempC/2)) * 2
	precip := 0
	if len(f.Daily) > 0 {
		precip = (f.Daily[0].PrecipProb / 20) * 20
	}
	day := 0
	if c.IsDay {
		day = 1
	}
	hi, lo := 0, 0
	if len(f.Daily) > 0 {
		hi, lo = int(f.Daily[0].HighC), int(f.Daily[0].LowC)
	}
	return fmt.Sprintf("%.1f,%.1f|%d|%s|%d|%d|%d|%d",
		f.Location.Lat, f.Location.Lon, tempBucket, c.Condition, precip, day, hi, lo)
}
