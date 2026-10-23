package skua

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"net/http"
	"time"
)

// swpcKpURL is the NOAA Space Weather Prediction Center planetary K-index feed.
const swpcKpURL = "https://services.swpc.noaa.gov/products/noaa-planetary-k-index.json"

// Aurora holds the current planetary Kp index and an estimate of whether the
// aurora may be visible at a location.
type Aurora struct {
	// Time is the observation time in UTC.
	Time time.Time `json:"time"`
	// Kp is the planetary K-index, a global geomagnetic activity value 0 to 9.
	Kp float64 `json:"kp"`
	// Level is the descriptive activity band for the Kp value.
	Level string `json:"level"`
	// Visible estimates whether the aurora may reach the location's latitude.
	Visible bool `json:"visible"`
}

// AuroraProvider fetches the current planetary Kp and aurora visibility.
type AuroraProvider interface {
	// Aurora returns the current Kp and visibility estimate for loc.
	Aurora(ctx context.Context, loc Location) (Aurora, error)
}

// AuroraProviderFunc adapts an ordinary function to an AuroraProvider.
type AuroraProviderFunc func(ctx context.Context, loc Location) (Aurora, error)

// Aurora calls f.
func (f AuroraProviderFunc) Aurora(ctx context.Context, loc Location) (Aurora, error) {
	return f(ctx, loc)
}

// SWPCAurora is an AuroraProvider backed by the free NOAA SWPC Kp feed. The Kp
// value is global; the visibility estimate uses the request's latitude.
type SWPCAurora struct {
	// client is the HTTP client used for requests.
	client *http.Client
	// baseURL is the Kp feed, overridable for testing.
	baseURL string
}

// SWPCAuroraOption configures a SWPCAurora provider.
type SWPCAuroraOption func(*SWPCAurora)

// NewSWPCAurora builds a SWPCAurora provider with sensible defaults.
func NewSWPCAurora(opts ...SWPCAuroraOption) *SWPCAurora {
	o := &SWPCAurora{
		client:  &http.Client{Timeout: 10 * time.Second},
		baseURL: swpcKpURL,
	}
	for _, opt := range opts {
		opt(o)
	}
	return o
}

// WithAuroraHTTPClient sets the HTTP client, mainly for tests.
func WithAuroraHTTPClient(c *http.Client) SWPCAuroraOption {
	return func(o *SWPCAurora) { o.client = c }
}

// WithAuroraBaseURL overrides the feed, mainly for tests.
func WithAuroraBaseURL(u string) SWPCAuroraOption {
	return func(o *SWPCAurora) { o.baseURL = u }
}

// swpcKpRow is one time-ordered reading in the NOAA planetary K-index feed.
type swpcKpRow struct {
	// TimeTag is the ISO 8601 observation time.
	TimeTag string `json:"time_tag"`
	// Kp is the planetary K-index for the interval.
	Kp float64 `json:"Kp"`
}

// Aurora fetches the latest planetary Kp and derives the level and a visibility
// estimate for loc. The feed is a time-ordered list of readings, newest last.
func (o *SWPCAurora) Aurora(ctx context.Context, loc Location) (Aurora, error) {
	if err := validateLocation(loc); err != nil {
		return Aurora{}, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, o.baseURL, nil)
	if err != nil {
		return Aurora{}, fmt.Errorf("%w: new request: %w", ErrProvider, err)
	}
	resp, err := o.client.Do(req)
	if err != nil {
		return Aurora{}, fmt.Errorf("%w: %w", ErrProvider, err)
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		return Aurora{}, fmt.Errorf("%w: status %d", ErrProvider, resp.StatusCode)
	}
	var rows []swpcKpRow
	if err := json.NewDecoder(resp.Body).Decode(&rows); err != nil {
		return Aurora{}, fmt.Errorf("%w: decode: %w", ErrProvider, err)
	}
	if len(rows) == 0 {
		return Aurora{}, fmt.Errorf("%w: no kp data", ErrProvider)
	}
	last := rows[len(rows)-1]
	obs, _ := time.Parse("2006-01-02T15:04:05", last.TimeTag)
	return Aurora{
		Time:    obs.UTC(),
		Kp:      last.Kp,
		Level:   auroraLevel(last.Kp),
		Visible: auroraVisible(last.Kp, loc.Lat),
	}, nil
}

// auroraLevel maps a Kp value to its descriptive geomagnetic activity band.
func auroraLevel(kp float64) string {
	switch {
	case kp < 3:
		return "Quiet"
	case kp < 4:
		return "Unsettled"
	case kp < 5:
		return "Active"
	case kp < 6:
		return "Minor storm (G1)"
	case kp < 7:
		return "Moderate storm (G2)"
	case kp < 8:
		return "Strong storm (G3)"
	case kp < 9:
		return "Severe storm (G4)"
	default:
		return "Extreme storm (G5)"
	}
}

// auroraVisible estimates whether the aurora may be overhead or on the horizon at
// lat given the planetary Kp. It uses the rough rule that the oval's equatorward
// boundary sits near 66 degrees at Kp 0 and drops about two degrees per Kp.
func auroraVisible(kp, lat float64) bool {
	boundary := 66.0 - 2.0*kp
	return math.Abs(lat) >= boundary
}
