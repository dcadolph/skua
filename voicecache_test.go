package skua

import (
	"context"
	"errors"
	"sync/atomic"
	"testing"
	"time"
)

// countingVoicer counts calls and returns a fixed voice or a set error.
type countingVoicer struct {
	// calls is the number of times Speak was invoked.
	calls int64
	// err is returned instead of a voice when non-nil.
	err error
}

// Speak records the call and returns the configured result.
func (p *countingVoicer) Speak(ctx context.Context, f Forecast, opts VoiceOpts) (Voice, error) {
	atomic.AddInt64(&p.calls, 1)
	if p.err != nil {
		return Voice{}, p.err
	}
	return Voice{Line: "cached"}, nil
}

// TestCachingVoicerHit serves similar weather from one upstream call.
func TestCachingVoicerHit(t *testing.T) {
	t.Parallel()
	stub := &countingVoicer{}
	cv := NewCachingVoicer(stub, WithVoiceTTL(time.Minute))
	f := sampleForecast()
	for i := 0; i < 3; i++ {
		if _, err := cv.Speak(context.Background(), f, VoiceOpts{Level: LevelProper}); err != nil {
			t.Fatalf("call %d: %v", i, err)
		}
	}
	if got := atomic.LoadInt64(&stub.calls); got != 1 {
		t.Errorf("upstream calls = %d, want 1", got)
	}
}

// TestCachingVoicerExpiry regenerates once the entry goes stale.
func TestCachingVoicerExpiry(t *testing.T) {
	t.Parallel()
	stub := &countingVoicer{}
	cv := NewCachingVoicer(stub, WithVoiceTTL(time.Minute))
	base := time.Unix(1000000000, 0)
	cv.now = func() time.Time { return base }
	f := sampleForecast()
	if _, err := cv.Speak(context.Background(), f, VoiceOpts{Level: LevelProper}); err != nil {
		t.Fatalf("first: %v", err)
	}
	cv.now = func() time.Time { return base.Add(2 * time.Minute) }
	if _, err := cv.Speak(context.Background(), f, VoiceOpts{Level: LevelProper}); err != nil {
		t.Fatalf("second: %v", err)
	}
	if got := atomic.LoadInt64(&stub.calls); got != 2 {
		t.Errorf("upstream calls = %d, want 2", got)
	}
}

// TestCachingVoicerErrorNotCached retries after an upstream error.
func TestCachingVoicerErrorNotCached(t *testing.T) {
	t.Parallel()
	stub := &countingVoicer{err: errors.New("boom")}
	cv := NewCachingVoicer(stub, WithVoiceTTL(time.Minute))
	f := sampleForecast()
	if _, err := cv.Speak(context.Background(), f, VoiceOpts{Level: LevelProper}); err == nil {
		t.Fatal("first: want error, got nil")
	}
	stub.err = nil
	if _, err := cv.Speak(context.Background(), f, VoiceOpts{Level: LevelProper}); err != nil {
		t.Fatalf("second: %v", err)
	}
	if got := atomic.LoadInt64(&stub.calls); got != 2 {
		t.Errorf("upstream calls = %d, want 2", got)
	}
}

// TestCachingVoicerLevelsSeparate confirms each level caches independently and a
// repeat of the same level is served from cache.
func TestCachingVoicerLevelsSeparate(t *testing.T) {
	t.Parallel()
	stub := &countingVoicer{}
	cv := NewCachingVoicer(stub, WithVoiceTTL(time.Minute))
	f := sampleForecast()
	for _, level := range []VoiceLevel{LevelProper, LevelSalty, LevelProper, LevelSalty} {
		if _, err := cv.Speak(context.Background(), f, VoiceOpts{Level: level}); err != nil {
			t.Fatalf("level %s: %v", level, err)
		}
	}
	if got := atomic.LoadInt64(&stub.calls); got != 2 {
		t.Errorf("upstream calls = %d, want 2 (one per distinct level)", got)
	}
}
