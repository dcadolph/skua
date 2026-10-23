package skua

import (
	"context"
	"sync/atomic"
	"testing"
	"time"
)

// countingAurora counts calls and returns a fixed reading.
type countingAurora struct {
	// calls is the number of times Aurora was invoked.
	calls int64
}

// Aurora records the call and returns a fixed reading.
func (p *countingAurora) Aurora(ctx context.Context, loc Location) (Aurora, error) {
	atomic.AddInt64(&p.calls, 1)
	return Aurora{Kp: 5, Level: "Minor storm (G1)"}, nil
}

// TestCachingAuroraHit serves a repeat request from cache.
func TestCachingAuroraHit(t *testing.T) {
	t.Parallel()
	stub := &countingAurora{}
	c := NewCachingAuroraProvider(stub)
	loc := Location{Lat: 65, Lon: 18}
	for i := 0; i < 3; i++ {
		if _, err := c.Aurora(context.Background(), loc); err != nil {
			t.Fatalf("call %d: %v", i, err)
		}
	}
	if got := atomic.LoadInt64(&stub.calls); got != 1 {
		t.Errorf("upstream calls = %d, want 1", got)
	}
}

// TestCachingAuroraExpiry refetches once the entry goes stale.
func TestCachingAuroraExpiry(t *testing.T) {
	t.Parallel()
	stub := &countingAurora{}
	c := NewCachingAuroraProvider(stub)
	base := time.Unix(1000000000, 0)
	c.cache.ttl = time.Minute
	c.cache.now = func() time.Time { return base }
	loc := Location{Lat: 65, Lon: 18}
	if _, err := c.Aurora(context.Background(), loc); err != nil {
		t.Fatalf("first: %v", err)
	}
	c.cache.now = func() time.Time { return base.Add(2 * time.Minute) }
	if _, err := c.Aurora(context.Background(), loc); err != nil {
		t.Fatalf("second: %v", err)
	}
	if got := atomic.LoadInt64(&stub.calls); got != 2 {
		t.Errorf("upstream calls = %d, want 2", got)
	}
}
