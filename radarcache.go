package skua

import (
	"context"
	"sync"
	"time"
)

// CachingRadarProvider serves the radar frame index from memory. The upstream
// index refreshes every few minutes and is identical for every viewer, so one
// cached value covers all requests.
type CachingRadarProvider struct {
	// next is the wrapped provider consulted on a cache miss.
	next RadarProvider
	// ttl is how long the cached index stays fresh.
	ttl time.Duration
	// now returns the current time and is overridable in tests.
	now func() time.Time
	// mu guards radar and expires.
	mu sync.RWMutex
	// radar is the cached frame set.
	radar Radar
	// expires is when the cached value stops being fresh.
	expires time.Time
}

// NewCachingRadarProvider wraps next with a single-value radar cache.
func NewCachingRadarProvider(next RadarProvider) *CachingRadarProvider {
	if next == nil {
		panic("NewCachingRadarProvider: next RadarProvider required")
	}
	return &CachingRadarProvider{next: next, ttl: 5 * time.Minute, now: time.Now}
}

// Radar returns the cached frame set when fresh, otherwise fetches and caches
// it. Errors are never cached.
func (c *CachingRadarProvider) Radar(ctx context.Context) (Radar, error) {
	c.mu.RLock()
	cached, expires := c.radar, c.expires
	c.mu.RUnlock()
	if len(cached.Frames) > 0 && c.now().Before(expires) {
		return cached, nil
	}

	r, err := c.next.Radar(ctx)
	if err != nil {
		return Radar{}, err
	}

	c.mu.Lock()
	c.radar, c.expires = r, c.now().Add(c.ttl)
	c.mu.Unlock()
	return r, nil
}
