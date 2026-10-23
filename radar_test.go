package skua

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/google/go-cmp/cmp"
)

// rainViewerBody is a canned RainViewer index with past and forecast frames.
const rainViewerBody = `{
  "version": "2.0",
  "generated": 1784518800,
  "host": "https://tilecache.rainviewer.com",
  "radar": {
    "past": [
      {"time": 1784515200, "path": "/v2/radar/aaa"},
      {"time": 1784518800, "path": "/v2/radar/bbb"}
    ],
    "nowcast": [
      {"time": 1784519400, "path": "/v2/radar/ccc"}
    ]
  },
  "satellite": {
    "infrared": [
      {"time": 1784518800, "path": "/v2/satellite/ddd"}
    ]
  }
}`

// TestRainViewerRadar verifies the index flattens into ordered frames.
func TestRainViewerRadar(t *testing.T) {
	t.Parallel()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(rainViewerBody))
	}))
	defer srv.Close()

	got, err := NewRainViewer(WithRadarBaseURL(srv.URL)).Radar(context.Background())
	if err != nil {
		t.Fatalf("Radar: %v", err)
	}
	want := Radar{
		Host: "https://tilecache.rainviewer.com",
		Frames: []RadarFrame{
			{Time: time.Unix(1784515200, 0).UTC(), Path: "/v2/radar/aaa"},
			{Time: time.Unix(1784518800, 0).UTC(), Path: "/v2/radar/bbb"},
			{Time: time.Unix(1784519400, 0).UTC(), Path: "/v2/radar/ccc", Future: true},
		},
		Satellite: []RadarFrame{
			{Time: time.Unix(1784518800, 0).UTC(), Path: "/v2/satellite/ddd"},
		},
	}
	if diff := cmp.Diff(want, got); diff != "" {
		t.Errorf("radar mismatch (-want +got):\n%s", diff)
	}
}

// TestRainViewerEmptyNowcast accepts an index with no forecast frames.
func TestRainViewerEmptyNowcast(t *testing.T) {
	t.Parallel()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`{"host":"https://t.example","radar":{"past":[{"time":1,"path":"/v2/radar/x"}],"nowcast":[]}}`))
	}))
	defer srv.Close()
	got, err := NewRainViewer(WithRadarBaseURL(srv.URL)).Radar(context.Background())
	if err != nil {
		t.Fatalf("Radar: %v", err)
	}
	if len(got.Frames) != 1 || got.Frames[0].Future {
		t.Errorf("frames = %+v, want one past frame", got.Frames)
	}
}

// TestRainViewerErrors covers a server error and an empty index.
func TestRainViewerErrors(t *testing.T) {
	t.Parallel()
	bad := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer bad.Close()
	if _, err := NewRainViewer(WithRadarBaseURL(bad.URL)).Radar(context.Background()); !errors.Is(err, ErrProvider) {
		t.Errorf("non-200: want ErrProvider, got %v", err)
	}
	empty := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`{"host":"https://t.example","radar":{"past":[],"nowcast":[]}}`))
	}))
	defer empty.Close()
	if _, err := NewRainViewer(WithRadarBaseURL(empty.URL)).Radar(context.Background()); !errors.Is(err, ErrProvider) {
		t.Errorf("empty index: want ErrProvider, got %v", err)
	}
}
