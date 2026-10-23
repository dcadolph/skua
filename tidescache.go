package skua

import (
	"context"
	"time"
)

// CachingTidesProvider serves recent tide extremes from memory. Predictions are
// fixed for the day, so a short cache spares repeated upstream calls per view.
type CachingTidesProvider struct {
	// cache memoizes results by location.
	cache *locationCache[Tides]
}

// NewCachingTidesProvider wraps next with an in-memory tide cache.
func NewCachingTidesProvider(next TidesProvider) *CachingTidesProvider {
	if next == nil {
		panic("NewCachingTidesProvider: next TidesProvider required")
	}
	return &CachingTidesProvider{cache: newLocationCache(next.Tides, 30*time.Minute)}
}

// Tides returns a cached reading when fresh, otherwise fetches and caches it.
func (c *CachingTidesProvider) Tides(ctx context.Context, loc Location) (Tides, error) {
	return c.cache.get(ctx, loc)
}
