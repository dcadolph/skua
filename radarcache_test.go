package skua

import (
	"context"
	"sync/atomic"
	"testing"
	"time"
)

// countingRadar counts calls and returns a fixed frame set.
type countingRadar struct {
	// calls is the number of times Radar was invoked.
	calls int64
}

// Radar records the call and returns a fixed frame set.
func (p *countingRadar) Radar(ctx context.Context) (Radar, error) {
	atomic.AddInt64(&p.calls, 1)
	return Radar{Host: "https://t.example", Frames: []RadarFrame{{Path: "/v2/radar/x"}}}, nil
}

// TestCachingRadarHit serves repeat requests from cache.
func TestCachingRadarHit(t *testing.T) {
	t.Parallel()
	stub := &countingRadar{}
	c := NewCachingRadarProvider(stub)
	for i := 0; i < 3; i++ {
		if _, err := c.Radar(context.Background()); err != nil {
			t.Fatalf("call %d: %v", i, err)
		}
	}
	if got := atomic.LoadInt64(&stub.calls); got != 1 {
		t.Errorf("upstream calls = %d, want 1", got)
	}
}

// TestCachingRadarExpiry refetches once the entry goes stale.
func TestCachingRadarExpiry(t *testing.T) {
	t.Parallel()
	stub := &countingRadar{}
	c := NewCachingRadarProvider(stub)
	base := time.Unix(1000000000, 0)
	c.ttl = time.Minute
	c.now = func() time.Time { return base }
	if _, err := c.Radar(context.Background()); err != nil {
		t.Fatalf("first: %v", err)
	}
	c.now = func() time.Time { return base.Add(2 * time.Minute) }
	if _, err := c.Radar(context.Background()); err != nil {
		t.Fatalf("second: %v", err)
	}
	if got := atomic.LoadInt64(&stub.calls); got != 2 {
		t.Errorf("upstream calls = %d, want 2", got)
	}
}
