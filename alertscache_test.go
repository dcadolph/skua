package skua

import (
	"context"
	"sync/atomic"
	"testing"
	"time"
)

// countingAlerts counts calls and returns a fixed alert set.
type countingAlerts struct {
	// calls is the number of times Alerts was invoked.
	calls int64
}

// Alerts records the call and returns a fixed alert set.
func (p *countingAlerts) Alerts(ctx context.Context, loc Location) (Alerts, error) {
	atomic.AddInt64(&p.calls, 1)
	return Alerts{Alerts: []Alert{{Event: "Flood Warning", Severity: "Severe"}}}, nil
}

// TestCachingAlertsHit serves a repeat request from cache.
func TestCachingAlertsHit(t *testing.T) {
	t.Parallel()
	stub := &countingAlerts{}
	c := NewCachingAlertsProvider(stub)
	loc := Location{Lat: 27.51, Lon: -99.51}
	for i := 0; i < 3; i++ {
		if _, err := c.Alerts(context.Background(), loc); err != nil {
			t.Fatalf("call %d: %v", i, err)
		}
	}
	if got := atomic.LoadInt64(&stub.calls); got != 1 {
		t.Errorf("upstream calls = %d, want 1", got)
	}
}

// TestCachingAlertsExpiry refetches once the entry goes stale.
func TestCachingAlertsExpiry(t *testing.T) {
	t.Parallel()
	stub := &countingAlerts{}
	c := NewCachingAlertsProvider(stub)
	base := time.Unix(1000000000, 0)
	c.cache.ttl = time.Minute
	c.cache.now = func() time.Time { return base }
	loc := Location{Lat: 27.51, Lon: -99.51}
	if _, err := c.Alerts(context.Background(), loc); err != nil {
		t.Fatalf("first: %v", err)
	}
	c.cache.now = func() time.Time { return base.Add(2 * time.Minute) }
	if _, err := c.Alerts(context.Background(), loc); err != nil {
		t.Fatalf("second: %v", err)
	}
	if got := atomic.LoadInt64(&stub.calls); got != 2 {
		t.Errorf("upstream calls = %d, want 2", got)
	}
}
