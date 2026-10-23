package skua

import (
	"context"
	"time"
)

// CachingLightningProvider serves recent storm risk from memory. Storms evolve
// faster than the sea or the tide, so the window is short.
type CachingLightningProvider struct {
	// cache memoizes results by location.
	cache *locationCache[Lightning]
}

// NewCachingLightningProvider wraps next with an in-memory storm-risk cache.
func NewCachingLightningProvider(next LightningProvider) *CachingLightningProvider {
	if next == nil {
		panic("NewCachingLightningProvider: next LightningProvider required")
	}
	return &CachingLightningProvider{cache: newLocationCache(next.Lightning, 15*time.Minute)}
}

// Lightning returns a cached reading when fresh, otherwise fetches and caches it.
func (c *CachingLightningProvider) Lightning(ctx context.Context, loc Location) (Lightning, error) {
	return c.cache.get(ctx, loc)
}
