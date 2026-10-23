package skua

import (
	"context"
	"time"
)

// CachingMarineProvider serves recent sea state from memory, since waves change
// slowly relative to a page view.
type CachingMarineProvider struct {
	// cache memoizes readings by location.
	cache *locationCache[Marine]
}

// NewCachingMarineProvider wraps next with an in-memory marine cache.
func NewCachingMarineProvider(next MarineProvider) *CachingMarineProvider {
	if next == nil {
		panic("NewCachingMarineProvider: next MarineProvider required")
	}
	return &CachingMarineProvider{cache: newLocationCache(next.Marine, 30*time.Minute)}
}

// Marine returns a cached reading when fresh, otherwise fetches and caches it.
func (c *CachingMarineProvider) Marine(ctx context.Context, loc Location) (Marine, error) {
	return c.cache.get(ctx, loc)
}
