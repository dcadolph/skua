package skua

import (
	"context"
	"fmt"
	"sync"
	"time"
)

// locationFetch loads a value of type T for a location.
type locationFetch[T any] func(ctx context.Context, loc Location) (T, error)

// locationCache memoizes location-keyed values with a TTL. It backs the marine
// and aurora providers, whose readings change slowly. Errors are never cached.
type locationCache[T any] struct {
	// fetch is the underlying loader consulted on a miss.
	fetch locationFetch[T]
	// ttl is how long a cached value stays fresh.
	ttl time.Duration
	// now returns the current time and is overridable in tests.
	now func() time.Time
	// mu guards entries.
	mu sync.RWMutex
	// entries holds cached values by rounded-location key.
	entries map[string]locEntry[T]
}

// locEntry is a stored value with its expiry.
type locEntry[T any] struct {
	// value is the cached result.
	value T
	// expires is when the entry stops being fresh.
	expires time.Time
}

// newLocationCache builds a location cache over fetch with the given TTL.
func newLocationCache[T any](fetch locationFetch[T], ttl time.Duration) *locationCache[T] {
	return &locationCache[T]{
		fetch:   fetch,
		ttl:     ttl,
		now:     time.Now,
		entries: make(map[string]locEntry[T]),
	}
}

// get returns a cached value when fresh, otherwise fetches and caches it. The
// key rounds the location to two decimals so nearby requests share an entry.
func (c *locationCache[T]) get(ctx context.Context, loc Location) (T, error) {
	key := fmt.Sprintf("%.2f,%.2f", loc.Lat, loc.Lon)

	c.mu.RLock()
	entry, ok := c.entries[key]
	c.mu.RUnlock()
	if ok && c.now().Before(entry.expires) {
		return entry.value, nil
	}

	v, err := c.fetch(ctx, loc)
	if err != nil {
		var zero T
		return zero, err
	}

	c.mu.Lock()
	c.entries[key] = locEntry[T]{value: v, expires: c.now().Add(c.ttl)}
	c.mu.Unlock()
	return v, nil
}
