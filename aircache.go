package skua

import (
	"context"
	"fmt"
	"sync"
	"time"
)

// CachingAirProvider wraps an AirQualityProvider and serves recent readings from
// memory, since air quality changes slowly.
type CachingAirProvider struct {
	// next is the wrapped provider consulted on a cache miss.
	next AirQualityProvider
	// ttl is how long a cached reading stays fresh.
	ttl time.Duration
	// now returns the current time and is overridable in tests.
	now func() time.Time
	// mu guards entries.
	mu sync.RWMutex
	// entries holds cached readings by rounded-location key.
	entries map[string]airEntry
}

// airEntry is a stored air-quality reading with its expiry.
type airEntry struct {
	// air is the cached reading.
	air AirQuality
	// expires is when the entry stops being fresh.
	expires time.Time
}

// CachingAirOption configures a CachingAirProvider.
type CachingAirOption func(*CachingAirProvider)

// NewCachingAirProvider wraps next with an in-memory air-quality cache.
func NewCachingAirProvider(next AirQualityProvider, opts ...CachingAirOption) *CachingAirProvider {
	if next == nil {
		panic("NewCachingAirProvider: next AirQualityProvider required")
	}
	c := &CachingAirProvider{
		next:    next,
		ttl:     15 * time.Minute,
		now:     time.Now,
		entries: make(map[string]airEntry),
	}
	for _, opt := range opts {
		opt(c)
	}
	return c
}

// WithAirTTL sets how long a cached reading stays fresh.
func WithAirTTL(d time.Duration) CachingAirOption {
	return func(c *CachingAirProvider) { c.ttl = d }
}

// AirQuality returns a cached reading when fresh, otherwise fetches from the
// wrapped provider and caches the result. Errors are never cached.
func (c *CachingAirProvider) AirQuality(ctx context.Context, loc Location) (AirQuality, error) {
	key := fmt.Sprintf("%.2f,%.2f", loc.Lat, loc.Lon)

	c.mu.RLock()
	entry, ok := c.entries[key]
	c.mu.RUnlock()
	if ok && c.now().Before(entry.expires) {
		return entry.air, nil
	}

	a, err := c.next.AirQuality(ctx, loc)
	if err != nil {
		return AirQuality{}, err
	}

	c.mu.Lock()
	c.entries[key] = airEntry{air: a, expires: c.now().Add(c.ttl)}
	c.mu.Unlock()
	return a, nil
}
