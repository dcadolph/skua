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

// openMeteoAirBaseURL is the default Open-Meteo air-quality endpoint.
const openMeteoAirBaseURL = "https://air-quality-api.open-meteo.com/v1/air-quality"

// AirQuality holds current air-quality conditions for a location.
type AirQuality struct {
	// Time is the observation time in UTC.
	Time time.Time `json:"time"`
	// Category is the descriptive US AQI band.
	Category string `json:"category"`
	// USAQI is the United States Air Quality Index.
	USAQI int `json:"usAqi"`
	// PM25 is fine particulate matter in micrograms per cubic meter.
	PM25 float64 `json:"pm25"`
	// PM10 is coarse particulate matter in micrograms per cubic meter.
	PM10 float64 `json:"pm10"`
	// Ozone is ground-level ozone in micrograms per cubic meter.
	Ozone float64 `json:"ozone"`
	// NO2 is nitrogen dioxide in micrograms per cubic meter.
	NO2 float64 `json:"no2"`
	// UVIndex is the current UV index.
	UVIndex float64 `json:"uvIndex"`
}

// AirQualityProvider fetches current air quality for a location.
type AirQualityProvider interface {
	// AirQuality returns the current air quality for loc.
	AirQuality(ctx context.Context, loc Location) (AirQuality, error)
}

// AirQualityProviderFunc adapts an ordinary function to an AirQualityProvider.
type AirQualityProviderFunc func(ctx context.Context, loc Location) (AirQuality, error)

// AirQuality calls f.
func (f AirQualityProviderFunc) AirQuality(ctx context.Context, loc Location) (AirQuality, error) {
	return f(ctx, loc)
}

// OpenMeteoAir is an AirQualityProvider backed by the free Open-Meteo air-quality API.
type OpenMeteoAir struct {
	// client is the HTTP client used for requests.
	client *http.Client
	// baseURL is the air-quality endpoint, overridable for testing.
	baseURL string
}

// OpenMeteoAirOption configures an OpenMeteoAir provider.
type OpenMeteoAirOption func(*OpenMeteoAir)

// NewOpenMeteoAir builds an OpenMeteoAir provider with sensible defaults.
func NewOpenMeteoAir(opts ...OpenMeteoAirOption) *OpenMeteoAir {
	o := &OpenMeteoAir{
		client:  &http.Client{Timeout: 10 * time.Second},
		baseURL: openMeteoAirBaseURL,
	}
	for _, opt := range opts {
		opt(o)
	}
	return o
}

// WithAirHTTPClient sets the HTTP client, mainly for tests.
func WithAirHTTPClient(c *http.Client) OpenMeteoAirOption {
	return func(o *OpenMeteoAir) { o.client = c }
}

// WithAirBaseURL overrides the endpoint, mainly for tests.
func WithAirBaseURL(u string) OpenMeteoAirOption {
	return func(o *OpenMeteoAir) { o.baseURL = u }
}

// AirQuality fetches and normalizes the Open-Meteo air quality for loc.
func (o *OpenMeteoAir) AirQuality(ctx context.Context, loc Location) (AirQuality, error) {
	if err := validateLocation(loc); err != nil {
		return AirQuality{}, err
	}
	endpoint, err := o.buildURL(loc)
	if err != nil {
		return AirQuality{}, fmt.Errorf("%w: build url: %w", ErrProvider, err)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return AirQuality{}, fmt.Errorf("%w: new request: %w", ErrProvider, err)
	}
	resp, err := o.client.Do(req)
	if err != nil {
		return AirQuality{}, fmt.Errorf("%w: %w", ErrProvider, err)
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		return AirQuality{}, fmt.Errorf("%w: status %d", ErrProvider, resp.StatusCode)
	}
	var raw openMeteoAirResponse
	if err := json.NewDecoder(resp.Body).Decode(&raw); err != nil {
		return AirQuality{}, fmt.Errorf("%w: decode: %w", ErrProvider, err)
	}
	return raw.normalize(), nil
}

// buildURL assembles the Open-Meteo air-quality request URL for loc.
func (o *OpenMeteoAir) buildURL(loc Location) (string, error) {
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
		"us_aqi", "pm2_5", "pm10", "ozone", "nitrogen_dioxide", "uv_index",
	}, ","))
	u.RawQuery = q.Encode()
	return u.String(), nil
}

// openMeteoAirResponse is the raw JSON returned by the air-quality API.
type openMeteoAirResponse struct {
	// Current is the present air-quality block.
	Current openMeteoAirCurrent `json:"current"`
}

// openMeteoAirCurrent is the current block of an air-quality response.
type openMeteoAirCurrent struct {
	// Time is the observation epoch in seconds.
	Time int64 `json:"time"`
	// USAQI is the United States Air Quality Index.
	USAQI float64 `json:"us_aqi"`
	// PM25 is fine particulate matter.
	PM25 float64 `json:"pm2_5"`
	// PM10 is coarse particulate matter.
	PM10 float64 `json:"pm10"`
	// Ozone is ground-level ozone.
	Ozone float64 `json:"ozone"`
	// NO2 is nitrogen dioxide.
	NO2 float64 `json:"nitrogen_dioxide"`
	// UVIndex is the current UV index.
	UVIndex float64 `json:"uv_index"`
}

// normalize converts a raw air-quality response into an AirQuality.
func (r openMeteoAirResponse) normalize() AirQuality {
	aqi := int(math.Round(r.Current.USAQI))
	return AirQuality{
		Time:     time.Unix(r.Current.Time, 0).UTC(),
		Category: aqiCategory(aqi),
		USAQI:    aqi,
		PM25:     r.Current.PM25,
		PM10:     r.Current.PM10,
		Ozone:    r.Current.Ozone,
		NO2:      r.Current.NO2,
		UVIndex:  r.Current.UVIndex,
	}
}

// aqiCategory maps a US AQI value to its descriptive band.
func aqiCategory(aqi int) string {
	switch {
	case aqi <= 50:
		return "Good"
	case aqi <= 100:
		return "Moderate"
	case aqi <= 150:
		return "Unhealthy for sensitive groups"
	case aqi <= 200:
		return "Unhealthy"
	case aqi <= 300:
		return "Very unhealthy"
	default:
		return "Hazardous"
	}
}
