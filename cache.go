package skua

import (
	"context"
	"fmt"
	"sync"
	"time"
)

// CachingProvider wraps a Provider and serves recent forecasts from memory,
// collapsing nearby requests onto one upstream call to keep data costs low.
type CachingProvider struct {
	// next is the wrapped provider consulted on a cache miss.
	next Provider
	// ttl is how long a cached forecast stays fresh.
	ttl time.Duration
	// precision is the decimal places lat and lon are rounded to for the key.
	precision int
	// now returns the current time and is overridable in tests.
	now func() time.Time
	// mu guards entries.
	mu sync.RWMutex
	// entries holds cached forecasts by rounded-location key.
	entries map[string]cacheEntry
}

// cacheEntry is a stored forecast with its expiry.
type cacheEntry struct {
	// forecast is the cached result.
	forecast Forecast
	// expires is when the entry stops being fresh.
	expires time.Time
}

// CachingOption configures a CachingProvider.
type CachingOption func(*CachingProvider)

// NewCachingProvider wraps next with an in-memory forecast cache.
func NewCachingProvider(next Provider, opts ...CachingOption) *CachingProvider {
	if next == nil {
		panic("NewCachingProvider: next Provider required")
	}
	c := &CachingProvider{
		next:      next,
		ttl:       10 * time.Minute,
		precision: 2,
		now:       time.Now,
		entries:   make(map[string]cacheEntry),
	}
	for _, opt := range opts {
		opt(c)
	}
	return c
}

// WithTTL sets how long a cached forecast stays fresh.
func WithTTL(d time.Duration) CachingOption {
	return func(c *CachingProvider) { c.ttl = d }
}

// WithPrecision sets the decimal places lat and lon are rounded to for the
// cache key. Fewer places means more nearby requests share one forecast.
func WithPrecision(places int) CachingOption {
	return func(c *CachingProvider) { c.precision = places }
}

// Forecast returns a cached forecast when fresh, otherwise fetches from the
// wrapped provider and caches the result. Errors are never cached.
func (c *CachingProvider) Forecast(ctx context.Context, loc Location) (Forecast, error) {
	key := c.key(loc)

	c.mu.RLock()
	entry, ok := c.entries[key]
	c.mu.RUnlock()
	if ok && c.now().Before(entry.expires) {
		return entry.forecast, nil
	}

	fc, err := c.next.Forecast(ctx, loc)
	if err != nil {
		return Forecast{}, err
	}

	c.mu.Lock()
	c.entries[key] = cacheEntry{forecast: fc, expires: c.now().Add(c.ttl)}
	c.mu.Unlock()
	return fc, nil
}

// key builds the cache key from loc, rounded to the configured precision.
func (c *CachingProvider) key(loc Location) string {
	return fmt.Sprintf("%.*f,%.*f", c.precision, loc.Lat, c.precision, loc.Lon)
}
