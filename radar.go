package skua

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

// rainViewerIndexURL is the RainViewer index of available radar frames.
const rainViewerIndexURL = "https://api.rainviewer.com/public/weather-maps.json"

// RadarFrame is one radar tile layer the client can render.
type RadarFrame struct {
	// Time is the frame's observation or forecast time in UTC.
	Time time.Time `json:"time"`
	// Path is the tile path fragment appended to the host.
	Path string `json:"path"`
	// Future reports whether the frame is a forecast rather than an observation.
	Future bool `json:"future"`
}

// Radar is the set of renderable radar frames. Clients compose tile URLs as
// host + frame path + /{size}/{z}/{x}/{y}/{color}/{options}.png.
type Radar struct {
	// Host is the tile server base URL.
	Host string `json:"host"`
	// Frames holds past then forecast frames in chronological order. Forecast
	// frames are sometimes absent from the upstream index.
	Frames []RadarFrame `json:"frames"`
	// Satellite holds infrared satellite frames in chronological order, empty
	// when the upstream index has none.
	Satellite []RadarFrame `json:"satellite,omitempty"`
}

// RadarProvider fetches the current set of radar frames.
type RadarProvider interface {
	// Radar returns the renderable radar frames.
	Radar(ctx context.Context) (Radar, error)
}

// RadarProviderFunc adapts an ordinary function to a RadarProvider.
type RadarProviderFunc func(ctx context.Context) (Radar, error)

// Radar calls f.
func (f RadarProviderFunc) Radar(ctx context.Context) (Radar, error) {
	return f(ctx)
}

// RainViewer is a RadarProvider backed by the free RainViewer index.
type RainViewer struct {
	// client is the HTTP client used for requests.
	client *http.Client
	// baseURL is the index endpoint, overridable for testing.
	baseURL string
}

// RainViewerOption configures a RainViewer provider.
type RainViewerOption func(*RainViewer)

// NewRainViewer builds a RainViewer provider with sensible defaults.
func NewRainViewer(opts ...RainViewerOption) *RainViewer {
	o := &RainViewer{
		client:  &http.Client{Timeout: 10 * time.Second},
		baseURL: rainViewerIndexURL,
	}
	for _, opt := range opts {
		opt(o)
	}
	return o
}

// WithRadarHTTPClient sets the HTTP client, mainly for tests.
func WithRadarHTTPClient(c *http.Client) RainViewerOption {
	return func(o *RainViewer) { o.client = c }
}

// WithRadarBaseURL overrides the index endpoint, mainly for tests.
func WithRadarBaseURL(u string) RainViewerOption {
	return func(o *RainViewer) { o.baseURL = u }
}

// rainViewerIndex is the raw JSON returned by the RainViewer index.
type rainViewerIndex struct {
	// Host is the tile server base URL.
	Host string `json:"host"`
	// Radar holds the past and forecast frame lists.
	Radar struct {
		// Past holds observed frames, oldest first.
		Past []rainViewerFrame `json:"past"`
		// Nowcast holds short-term forecast frames, sometimes empty.
		Nowcast []rainViewerFrame `json:"nowcast"`
	} `json:"radar"`
	// Satellite holds the infrared frame list.
	Satellite struct {
		// Infrared holds observed satellite frames, oldest first.
		Infrared []rainViewerFrame `json:"infrared"`
	} `json:"satellite"`
}

// rainViewerFrame is one frame entry in the RainViewer index.
type rainViewerFrame struct {
	// Time is the frame epoch in seconds.
	Time int64 `json:"time"`
	// Path is the tile path fragment.
	Path string `json:"path"`
}

// Radar fetches the RainViewer index and flattens it into renderable frames.
func (o *RainViewer) Radar(ctx context.Context) (Radar, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, o.baseURL, nil)
	if err != nil {
		return Radar{}, fmt.Errorf("%w: new request: %w", ErrProvider, err)
	}
	resp, err := o.client.Do(req)
	if err != nil {
		return Radar{}, fmt.Errorf("%w: %w", ErrProvider, err)
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		return Radar{}, fmt.Errorf("%w: status %d", ErrProvider, resp.StatusCode)
	}
	var raw rainViewerIndex
	if err := json.NewDecoder(resp.Body).Decode(&raw); err != nil {
		return Radar{}, fmt.Errorf("%w: decode: %w", ErrProvider, err)
	}
	if raw.Host == "" || len(raw.Radar.Past) == 0 {
		return Radar{}, fmt.Errorf("%w: no radar frames", ErrProvider)
	}
	r := Radar{Host: raw.Host}
	for _, f := range raw.Radar.Past {
		r.Frames = append(r.Frames, RadarFrame{Time: time.Unix(f.Time, 0).UTC(), Path: f.Path})
	}
	for _, f := range raw.Radar.Nowcast {
		r.Frames = append(r.Frames, RadarFrame{Time: time.Unix(f.Time, 0).UTC(), Path: f.Path, Future: true})
	}
	for _, f := range raw.Satellite.Infrared {
		r.Satellite = append(r.Satellite, RadarFrame{Time: time.Unix(f.Time, 0).UTC(), Path: f.Path})
	}
	return r, nil
}
