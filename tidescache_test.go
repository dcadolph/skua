package skua

import (
	"context"
	"sync/atomic"
	"testing"
	"time"
)

// countingTides counts calls and returns a fixed reading.
type countingTides struct {
	// calls is the number of times Tides was invoked.
	calls int64
}

// Tides records the call and returns a fixed reading.
func (p *countingTides) Tides(ctx context.Context, loc Location) (Tides, error) {
	atomic.AddInt64(&p.calls, 1)
	return Tides{Available: true, StationName: "San Diego"}, nil
}

// TestCachingTidesHit serves a repeat request from cache.
func TestCachingTidesHit(t *testing.T) {
	t.Parallel()
	stub := &countingTides{}
	c := NewCachingTidesProvider(stub)
	loc := Location{Lat: 32.7, Lon: -117.2}
	for i := 0; i < 3; i++ {
		if _, err := c.Tides(context.Background(), loc); err != nil {
			t.Fatalf("call %d: %v", i, err)
		}
	}
	if got := atomic.LoadInt64(&stub.calls); got != 1 {
		t.Errorf("upstream calls = %d, want 1", got)
	}
}

// TestCachingTidesExpiry refetches once the entry goes stale.
func TestCachingTidesExpiry(t *testing.T) {
	t.Parallel()
	stub := &countingTides{}
	c := NewCachingTidesProvider(stub)
	base := time.Unix(1000000000, 0)
	c.cache.ttl = time.Minute
	c.cache.now = func() time.Time { return base }
	loc := Location{Lat: 32.7, Lon: -117.2}
	if _, err := c.Tides(context.Background(), loc); err != nil {
		t.Fatalf("first: %v", err)
	}
	c.cache.now = func() time.Time { return base.Add(2 * time.Minute) }
	if _, err := c.Tides(context.Background(), loc); err != nil {
		t.Fatalf("second: %v", err)
	}
	if got := atomic.LoadInt64(&stub.calls); got != 2 {
		t.Errorf("upstream calls = %d, want 2", got)
	}
}
