package skua

import (
	"context"
	"time"
)

// CachingAuroraProvider serves the planetary Kp from memory. The feed updates a
// few times an hour, so a short cache spares NOAA repeated calls.
type CachingAuroraProvider struct {
	// cache memoizes readings by location, since visibility depends on latitude.
	cache *locationCache[Aurora]
}

// NewCachingAuroraProvider wraps next with an in-memory aurora cache.
func NewCachingAuroraProvider(next AuroraProvider) *CachingAuroraProvider {
	if next == nil {
		panic("NewCachingAuroraProvider: next AuroraProvider required")
	}
	return &CachingAuroraProvider{cache: newLocationCache(next.Aurora, 20*time.Minute)}
}

// Aurora returns a cached reading when fresh, otherwise fetches and caches it.
func (c *CachingAuroraProvider) Aurora(ctx context.Context, loc Location) (Aurora, error) {
	return c.cache.get(ctx, loc)
}
