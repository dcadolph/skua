package skua

import (
	"context"
	"time"
)

// CachingAlertsProvider serves recent alert reads from memory. The TTL is short
// because alerts are safety information.
type CachingAlertsProvider struct {
	// cache memoizes alert sets by location.
	cache *locationCache[Alerts]
}

// NewCachingAlertsProvider wraps next with an in-memory alerts cache.
func NewCachingAlertsProvider(next AlertsProvider) *CachingAlertsProvider {
	if next == nil {
		panic("NewCachingAlertsProvider: next AlertsProvider required")
	}
	return &CachingAlertsProvider{cache: newLocationCache(next.Alerts, 2*time.Minute)}
}

// Alerts returns a cached alert set when fresh, otherwise fetches and caches it.
func (c *CachingAlertsProvider) Alerts(ctx context.Context, loc Location) (Alerts, error) {
	return c.cache.get(ctx, loc)
}
