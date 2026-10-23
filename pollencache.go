package skua

import (
	"context"
	"sync"
	"time"
)

// CachingPollenProvider wraps a PollenProvider and serves recent readings from
// memory, since pollen forecasts change slowly.
type CachingPollenProvider struct {
	// next is the wrapped provider consulted on a cache miss.
	next PollenProvider
	// ttl is how long a cached reading stays fresh.
	ttl time.Duration
	// now returns the current time and is overridable in tests.
	now func() time.Time
	// mu guards entries.
	mu sync.RWMutex
	// entries holds cached readings by ZIP key.
	entries map[string]pollenEntry
}

// pollenEntry is a stored pollen reading with its expiry.
type pollenEntry struct {
	// pollen is the cached reading.
	pollen Pollen
	// expires is when the entry stops being fresh.
	expires time.Time
}

// CachingPollenOption configures a CachingPollenProvider.
type CachingPollenOption func(*CachingPollenProvider)

// NewCachingPollenProvider wraps next with an in-memory pollen cache.
func NewCachingPollenProvider(next PollenProvider, opts ...CachingPollenOption) *CachingPollenProvider {
	if next == nil {
		panic("NewCachingPollenProvider: next PollenProvider required")
	}
	c := &CachingPollenProvider{
		next:    next,
		ttl:     3 * time.Hour,
		now:     time.Now,
		entries: make(map[string]pollenEntry),
	}
	for _, opt := range opts {
		opt(c)
	}
	return c
}

// WithPollenTTL sets how long a cached reading stays fresh.
func WithPollenTTL(d time.Duration) CachingPollenOption {
	return func(c *CachingPollenProvider) { c.ttl = d }
}

// Pollen returns a cached reading when fresh, otherwise fetches from the
// wrapped provider and caches the result. Errors are never cached.
func (c *CachingPollenProvider) Pollen(ctx context.Context, zip string) (Pollen, error) {
	c.mu.RLock()
	entry, ok := c.entries[zip]
	c.mu.RUnlock()
	if ok && c.now().Before(entry.expires) {
		return entry.pollen, nil
	}

	p, err := c.next.Pollen(ctx, zip)
	if err != nil {
		return Pollen{}, err
	}

	c.mu.Lock()
	c.entries[zip] = pollenEntry{pollen: p, expires: c.now().Add(c.ttl)}
	c.mu.Unlock()
	return p, nil
}
