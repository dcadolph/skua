package skua

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
)

// openMeteoMarineBaseURL is the default Open-Meteo marine endpoint.
const openMeteoMarineBaseURL = "https://marine-api.open-meteo.com/v1/marine"

// Marine holds current sea state for a coastal location. Available is false for
// inland points where the marine model has no data, which is how the client
// knows to hide the panel.
type Marine struct {
	// Available reports whether marine data exists for the location.
	Available bool `json:"available"`
	// Time is the observation time in UTC.
	Time time.Time `json:"time"`
	// WaveHeightM is the combined significant wave height in meters.
	WaveHeightM float64 `json:"waveHeightM"`
	// WaveDirectionDeg is the mean wave direction in degrees.
	WaveDirectionDeg int `json:"waveDirectionDeg"`
	// WavePeriodS is the mean wave period in seconds.
	WavePeriodS float64 `json:"wavePeriodS"`
	// SwellHeightM is the swell wave height in meters.
	SwellHeightM float64 `json:"swellHeightM"`
	// SwellPeriodS is the swell wave period in seconds.
	SwellPeriodS float64 `json:"swellPeriodS"`
}

// MarineProvider fetches current sea state for a location.
type MarineProvider interface {
	// Marine returns the current sea state for loc.
	Marine(ctx context.Context, loc Location) (Marine, error)
}

// MarineProviderFunc adapts an ordinary function to a MarineProvider.
type MarineProviderFunc func(ctx context.Context, loc Location) (Marine, error)

// Marine calls f.
func (f MarineProviderFunc) Marine(ctx context.Context, loc Location) (Marine, error) {
	return f(ctx, loc)
}

// OpenMeteoMarine is a MarineProvider backed by the free Open-Meteo marine API.
type OpenMeteoMarine struct {
	// client is the HTTP client used for requests.
	client *http.Client
	// baseURL is the marine endpoint, overridable for testing.
	baseURL string
}

// OpenMeteoMarineOption configures an OpenMeteoMarine provider.
type OpenMeteoMarineOption func(*OpenMeteoMarine)

// NewOpenMeteoMarine builds an OpenMeteoMarine provider with sensible defaults.
func NewOpenMeteoMarine(opts ...OpenMeteoMarineOption) *OpenMeteoMarine {
	o := &OpenMeteoMarine{
		client:  &http.Client{Timeout: 10 * time.Second},
		baseURL: openMeteoMarineBaseURL,
	}
	for _, opt := range opts {
		opt(o)
	}
	return o
}

// WithMarineHTTPClient sets the HTTP client, mainly for tests.
func WithMarineHTTPClient(c *http.Client) OpenMeteoMarineOption {
	return func(o *OpenMeteoMarine) { o.client = c }
}

// WithMarineBaseURL overrides the endpoint, mainly for tests.
func WithMarineBaseURL(u string) OpenMeteoMarineOption {
	return func(o *OpenMeteoMarine) { o.baseURL = u }
}

// Marine fetches and normalizes the Open-Meteo sea state for loc. An inland
// location with no marine data returns an unavailable Marine, not an error.
func (o *OpenMeteoMarine) Marine(ctx context.Context, loc Location) (Marine, error) {
	if err := validateLocation(loc); err != nil {
		return Marine{}, err
	}
	endpoint, err := o.buildURL(loc)
	if err != nil {
		return Marine{}, fmt.Errorf("%w: build url: %w", ErrProvider, err)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return Marine{}, fmt.Errorf("%w: new request: %w", ErrProvider, err)
	}
	resp, err := o.client.Do(req)
	if err != nil {
		return Marine{}, fmt.Errorf("%w: %w", ErrProvider, err)
	}
	defer func() { _ = resp.Body.Close() }()
	// The marine model returns 400 for inland points with no data. Treat that as
	// simply unavailable rather than an error.
	if resp.StatusCode == http.StatusBadRequest {
		return Marine{Available: false}, nil
	}
	if resp.StatusCode != http.StatusOK {
		return Marine{}, fmt.Errorf("%w: status %d", ErrProvider, resp.StatusCode)
	}
	var raw openMeteoMarineResponse
	if err := json.NewDecoder(resp.Body).Decode(&raw); err != nil {
		return Marine{}, fmt.Errorf("%w: decode: %w", ErrProvider, err)
	}
	return raw.normalize(), nil
}

// buildURL assembles the Open-Meteo marine request URL for loc.
func (o *OpenMeteoMarine) buildURL(loc Location) (string, error) {
	u, err := url.Parse(o.baseURL)
	if err != nil {
		return "", err
	}
	q := url.Values{}
	q.Set("latitude", strconv.FormatFloat(loc.Lat, 'f', -1, 64))
	q.Set("longitude", strconv.FormatFloat(loc.Lon, 'f', -1, 64))
	q.Set("timeformat", "unixtime")
	q.Set("timezone", "auto")
	q.Set("current", strings.Join([]string{
		"wave_height", "wave_direction", "wave_period",
		"swell_wave_height", "swell_wave_period",
	}, ","))
	u.RawQuery = q.Encode()
	return u.String(), nil
}

// openMeteoMarineResponse is the raw JSON returned by the marine API.
type openMeteoMarineResponse struct {
	// Current is the present sea-state block.
	Current openMeteoMarineCurrent `json:"current"`
}

// openMeteoMarineCurrent is the current block of a marine response. WaveHeight is
// a pointer so an absent value at an inland point is distinct from a real zero.
type openMeteoMarineCurrent struct {
	// Time is the observation epoch in seconds.
	Time int64 `json:"time"`
	// WaveHeight is the combined wave height in meters, nil when inland.
	WaveHeight *float64 `json:"wave_height"`
	// WaveDirection is the mean wave direction in degrees.
	WaveDirection float64 `json:"wave_direction"`
	// WavePeriod is the mean wave period in seconds.
	WavePeriod float64 `json:"wave_period"`
	// SwellHeight is the swell wave height in meters.
	SwellHeight float64 `json:"swell_wave_height"`
	// SwellPeriod is the swell wave period in seconds.
	SwellPeriod float64 `json:"swell_wave_period"`
}

// normalize converts a raw marine response into a Marine. A nil wave height marks
// the location as having no marine data.
func (r openMeteoMarineResponse) normalize() Marine {
	if r.Current.WaveHeight == nil {
		return Marine{Available: false}
	}
	return Marine{
		Available:        true,
		Time:             time.Unix(r.Current.Time, 0).UTC(),
		WaveHeightM:      *r.Current.WaveHeight,
		WaveDirectionDeg: int(math.Round(r.Current.WaveDirection)),
		WavePeriodS:      r.Current.WavePeriod,
		SwellHeightM:     r.Current.SwellHeight,
		SwellPeriodS:     r.Current.SwellPeriod,
	}
}
