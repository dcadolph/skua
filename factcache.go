package skua

import (
	"context"
	"fmt"
	"sync"
	"time"
)

// CachingFactProvider wraps a FactProvider and serves recent facts from memory,
// since the fact of the day changes only once per calendar date.
type CachingFactProvider struct {
	// next is the wrapped provider consulted on a cache miss.
	next FactProvider
	// ttl is how long a cached fact stays fresh.
	ttl time.Duration
	// now returns the current time and is overridable in tests.
	now func() time.Time
	// mu guards entries.
	mu sync.RWMutex
	// entries holds cached facts by month-day key.
	entries map[string]factEntry
}

// factEntry is a stored fact with its expiry.
type factEntry struct {
	// fact is the cached fact.
	fact Fact
	// expires is when the entry stops being fresh.
	expires time.Time
}

// CachingFactOption configures a CachingFactProvider.
type CachingFactOption func(*CachingFactProvider)

// NewCachingFactProvider wraps next with an in-memory fact cache.
func NewCachingFactProvider(next FactProvider, opts ...CachingFactOption) *CachingFactProvider {
	if next == nil {
		panic("NewCachingFactProvider: next FactProvider required")
	}
	c := &CachingFactProvider{
		next:    next,
		ttl:     12 * time.Hour,
		now:     time.Now,
		entries: make(map[string]factEntry),
	}
	for _, opt := range opts {
		opt(c)
	}
	return c
}

// WithFactTTL sets how long a cached fact stays fresh.
func WithFactTTL(d time.Duration) CachingFactOption {
	return func(c *CachingFactProvider) { c.ttl = d }
}

// Fact returns a cached fact when fresh, otherwise fetches from the wrapped
// provider and caches the result. Errors are never cached.
func (c *CachingFactProvider) Fact(ctx context.Context, month, day int) (Fact, error) {
	key := fmt.Sprintf("%02d-%02d", month, day)

	c.mu.RLock()
	entry, ok := c.entries[key]
	c.mu.RUnlock()
	if ok && c.now().Before(entry.expires) {
		return entry.fact, nil
	}

	f, err := c.next.Fact(ctx, month, day)
	if err != nil {
		return Fact{}, err
	}

	c.mu.Lock()
	c.entries[key] = factEntry{fact: f, expires: c.now().Add(c.ttl)}
	c.mu.Unlock()
	return f, nil
}
