package skua

import (
	"context"
	"sync/atomic"
	"testing"
	"time"
)

// countingLightning counts calls and returns a fixed reading.
type countingLightning struct {
	// calls is the number of times Lightning was invoked.
	calls int64
}

// Lightning records the call and returns a fixed reading.
func (p *countingLightning) Lightning(ctx context.Context, loc Location) (Lightning, error) {
	atomic.AddInt64(&p.calls, 1)
	return Lightning{Risk: "high", Level: 3}, nil
}

// TestCachingLightningHit serves a repeat request from cache.
func TestCachingLightningHit(t *testing.T) {
	t.Parallel()
	stub := &countingLightning{}
	c := NewCachingLightningProvider(stub)
	loc := Location{Lat: 30.27, Lon: -97.74}
	for i := 0; i < 3; i++ {
		if _, err := c.Lightning(context.Background(), loc); err != nil {
			t.Fatalf("call %d: %v", i, err)
		}
	}
	if got := atomic.LoadInt64(&stub.calls); got != 1 {
		t.Errorf("upstream calls = %d, want 1", got)
	}
}

// TestCachingLightningExpiry refetches once the entry goes stale.
func TestCachingLightningExpiry(t *testing.T) {
	t.Parallel()
	stub := &countingLightning{}
	c := NewCachingLightningProvider(stub)
	base := time.Unix(1000000000, 0)
	c.cache.ttl = time.Minute
	c.cache.now = func() time.Time { return base }
	loc := Location{Lat: 30.27, Lon: -97.74}
	if _, err := c.Lightning(context.Background(), loc); err != nil {
		t.Fatalf("first: %v", err)
	}
	c.cache.now = func() time.Time { return base.Add(2 * time.Minute) }
	if _, err := c.Lightning(context.Background(), loc); err != nil {
		t.Fatalf("second: %v", err)
	}
	if got := atomic.LoadInt64(&stub.calls); got != 2 {
		t.Errorf("upstream calls = %d, want 2", got)
	}
}
