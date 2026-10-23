package skua

import (
	"context"
	"sync/atomic"
	"testing"
	"time"
)

// countingMarine counts calls and returns a fixed reading.
type countingMarine struct {
	// calls is the number of times Marine was invoked.
	calls int64
}

// Marine records the call and returns a fixed reading.
func (p *countingMarine) Marine(ctx context.Context, loc Location) (Marine, error) {
	atomic.AddInt64(&p.calls, 1)
	return Marine{Available: true, WaveHeightM: 1.2}, nil
}

// TestCachingMarineHit serves a repeat request from cache.
func TestCachingMarineHit(t *testing.T) {
	t.Parallel()
	stub := &countingMarine{}
	c := NewCachingMarineProvider(stub)
	loc := Location{Lat: 32.7, Lon: -117.2}
	for i := 0; i < 3; i++ {
		if _, err := c.Marine(context.Background(), loc); err != nil {
			t.Fatalf("call %d: %v", i, err)
		}
	}
	if got := atomic.LoadInt64(&stub.calls); got != 1 {
		t.Errorf("upstream calls = %d, want 1", got)
	}
}

// TestCachingMarineExpiry refetches once the entry goes stale.
func TestCachingMarineExpiry(t *testing.T) {
	t.Parallel()
	stub := &countingMarine{}
	c := NewCachingMarineProvider(stub)
	base := time.Unix(1000000000, 0)
	c.cache.ttl = time.Minute
	c.cache.now = func() time.Time { return base }
	loc := Location{Lat: 32.7, Lon: -117.2}
	if _, err := c.Marine(context.Background(), loc); err != nil {
		t.Fatalf("first: %v", err)
	}
	c.cache.now = func() time.Time { return base.Add(2 * time.Minute) }
	if _, err := c.Marine(context.Background(), loc); err != nil {
		t.Fatalf("second: %v", err)
	}
	if got := atomic.LoadInt64(&stub.calls); got != 2 {
		t.Errorf("upstream calls = %d, want 2", got)
	}
}
