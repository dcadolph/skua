package skua

import (
	"context"
	"errors"
	"sync/atomic"
	"testing"
	"time"
)

// countingProvider counts calls and returns a fixed forecast or a set error.
type countingProvider struct {
	// calls is the number of times Forecast was invoked.
	calls int64
	// err is returned instead of a forecast when non-nil.
	err error
}

// Forecast records the call and returns the configured result.
func (p *countingProvider) Forecast(ctx context.Context, loc Location) (Forecast, error) {
	atomic.AddInt64(&p.calls, 1)
	if p.err != nil {
		return Forecast{}, p.err
	}
	return Forecast{Source: "counting", Location: loc}, nil
}

// TestCachingProviderHit serves repeat requests from one upstream call.
func TestCachingProviderHit(t *testing.T) {
	t.Parallel()
	stub := &countingProvider{}
	cp := NewCachingProvider(stub, WithTTL(time.Minute))
	loc := Location{Lat: 30.27, Lon: -97.74}
	for i := 0; i < 3; i++ {
		if _, err := cp.Forecast(context.Background(), loc); err != nil {
			t.Fatalf("call %d: %v", i, err)
		}
	}
	if got := atomic.LoadInt64(&stub.calls); got != 1 {
		t.Errorf("upstream calls = %d, want 1", got)
	}
}

// TestCachingProviderExpiry refetches once the entry goes stale.
func TestCachingProviderExpiry(t *testing.T) {
	t.Parallel()
	stub := &countingProvider{}
	cp := NewCachingProvider(stub, WithTTL(time.Minute))
	base := time.Unix(1000000000, 0)
	cp.now = func() time.Time { return base }
	loc := Location{Lat: 40, Lon: -74}

	if _, err := cp.Forecast(context.Background(), loc); err != nil {
		t.Fatalf("first: %v", err)
	}
	cp.now = func() time.Time { return base.Add(2 * time.Minute) }
	if _, err := cp.Forecast(context.Background(), loc); err != nil {
		t.Fatalf("second: %v", err)
	}
	if got := atomic.LoadInt64(&stub.calls); got != 2 {
		t.Errorf("upstream calls = %d, want 2", got)
	}
}

// TestCachingProviderRoundsKey shares one forecast across nearby coordinates.
func TestCachingProviderRoundsKey(t *testing.T) {
	t.Parallel()
	stub := &countingProvider{}
	cp := NewCachingProvider(stub, WithTTL(time.Minute), WithPrecision(2))
	if _, err := cp.Forecast(context.Background(), Location{Lat: 30.271, Lon: -97.742}); err != nil {
		t.Fatalf("first: %v", err)
	}
	if _, err := cp.Forecast(context.Background(), Location{Lat: 30.274, Lon: -97.744}); err != nil {
		t.Fatalf("second: %v", err)
	}
	if got := atomic.LoadInt64(&stub.calls); got != 1 {
		t.Errorf("upstream calls = %d, want 1", got)
	}
}

// TestCachingProviderErrorNotCached retries after an upstream error.
func TestCachingProviderErrorNotCached(t *testing.T) {
	t.Parallel()
	stub := &countingProvider{err: errors.New("boom")}
	cp := NewCachingProvider(stub, WithTTL(time.Minute))
	loc := Location{Lat: 1, Lon: 1}

	if _, err := cp.Forecast(context.Background(), loc); err == nil {
		t.Fatal("first: want error, got nil")
	}
	stub.err = nil
	if _, err := cp.Forecast(context.Background(), loc); err != nil {
		t.Fatalf("second: %v", err)
	}
	if got := atomic.LoadInt64(&stub.calls); got != 2 {
		t.Errorf("upstream calls = %d, want 2", got)
	}
}

// TestCachingProviderDistinctLocations keeps far-apart coordinates separate.
func TestCachingProviderDistinctLocations(t *testing.T) {
	t.Parallel()
	stub := &countingProvider{}
	cp := NewCachingProvider(stub, WithTTL(time.Minute))
	if _, err := cp.Forecast(context.Background(), Location{Lat: 30, Lon: -97}); err != nil {
		t.Fatalf("first: %v", err)
	}
	if _, err := cp.Forecast(context.Background(), Location{Lat: 51, Lon: 0}); err != nil {
		t.Fatalf("second: %v", err)
	}
	if got := atomic.LoadInt64(&stub.calls); got != 2 {
		t.Errorf("upstream calls = %d, want 2", got)
	}
}
