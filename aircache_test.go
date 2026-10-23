package skua

import (
	"context"
	"sync/atomic"
	"testing"
	"time"
)

// countingAir counts calls and returns a fixed reading.
type countingAir struct {
	// calls is the number of times AirQuality was invoked.
	calls int64
}

// AirQuality records the call and returns a fixed reading.
func (p *countingAir) AirQuality(ctx context.Context, loc Location) (AirQuality, error) {
	atomic.AddInt64(&p.calls, 1)
	return AirQuality{USAQI: 42, Category: "Good"}, nil
}

// TestCachingAirHit serves a repeat request from cache.
func TestCachingAirHit(t *testing.T) {
	t.Parallel()
	stub := &countingAir{}
	c := NewCachingAirProvider(stub, WithAirTTL(time.Minute))
	loc := Location{Lat: 30.27, Lon: -97.74}
	for i := 0; i < 3; i++ {
		if _, err := c.AirQuality(context.Background(), loc); err != nil {
			t.Fatalf("call %d: %v", i, err)
		}
	}
	if got := atomic.LoadInt64(&stub.calls); got != 1 {
		t.Errorf("upstream calls = %d, want 1", got)
	}
}

// TestCachingAirExpiry refetches once the entry goes stale.
func TestCachingAirExpiry(t *testing.T) {
	t.Parallel()
	stub := &countingAir{}
	c := NewCachingAirProvider(stub, WithAirTTL(time.Minute))
	base := time.Unix(1000000000, 0)
	c.now = func() time.Time { return base }
	loc := Location{Lat: 40, Lon: -74}
	if _, err := c.AirQuality(context.Background(), loc); err != nil {
		t.Fatalf("first: %v", err)
	}
	c.now = func() time.Time { return base.Add(2 * time.Minute) }
	if _, err := c.AirQuality(context.Background(), loc); err != nil {
		t.Fatalf("second: %v", err)
	}
	if got := atomic.LoadInt64(&stub.calls); got != 2 {
		t.Errorf("upstream calls = %d, want 2", got)
	}
}
