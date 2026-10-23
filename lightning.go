package skua

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
)

// lightningHorizon is how far ahead storm risk is assessed.
const lightningHorizon = 12 * time.Hour

// lightningImminent is the window within which a storm counts as closing in.
const lightningImminent = 2 * time.Hour

// Thunderstorm WMO weather codes: slight or moderate, with hail, with heavy hail.
const (
	wmoThunderstorm = 95
	wmoThunderHail  = 96
	wmoThunderHeavy = 99
)

// CAPE thresholds in J/kg that push storm risk up a band.
const (
	capeHigh    = 2000.0
	capeExtreme = 3000.0
)

// Lightning is the near-term thunderstorm and strike risk for a location. Risk
// is none when the sky is quiet, which is how the client knows to hide the panel.
type Lightning struct {
	// Risk is the band: none, low, moderate, high, or extreme.
	Risk string `json:"risk"`
	// Level is the band as a number from 0 to 4.
	Level int `json:"level"`
	// Imminent reports whether a storm lands inside the imminent window.
	Imminent bool `json:"imminent"`
	// Next is the first forecast thunderstorm hour, zero when none is ahead.
	Next time.Time `json:"next"`
	// HasNext reports whether Next is set.
	HasNext bool `json:"hasNext"`
	// PeakCapeJPerKg is the peak convective energy in the risk window.
	PeakCapeJPerKg float64 `json:"peakCapeJPerKg"`
	// StormHours is the count of thunderstorm hours in the risk window.
	StormHours int `json:"stormHours"`
	// Headline is the bird's read on the storm risk.
	Headline string `json:"headline"`
}

// LightningProvider assesses near-term storm and strike risk for a location.
type LightningProvider interface {
	// Lightning returns the storm risk for loc.
	Lightning(ctx context.Context, loc Location) (Lightning, error)
}

// LightningProviderFunc adapts an ordinary function to a LightningProvider.
type LightningProviderFunc func(ctx context.Context, loc Location) (Lightning, error)

// Lightning calls f.
func (f LightningProviderFunc) Lightning(ctx context.Context, loc Location) (Lightning, error) {
	return f(ctx, loc)
}

// OpenMeteoLightning is a LightningProvider backed by Open-Meteo, reading CAPE,
// lightning potential, and thunderstorm codes to grade strike risk.
type OpenMeteoLightning struct {
	// client is the HTTP client used for requests.
	client *http.Client
	// baseURL is the forecast endpoint, overridable for testing.
	baseURL string
	// now returns the current time and is overridable in tests.
	now func() time.Time
}

// OpenMeteoLightningOption configures an OpenMeteoLightning provider.
type OpenMeteoLightningOption func(*OpenMeteoLightning)

// NewOpenMeteoLightning builds an OpenMeteoLightning provider with defaults.
func NewOpenMeteoLightning(opts ...OpenMeteoLightningOption) *OpenMeteoLightning {
	o := &OpenMeteoLightning{
		client:  &http.Client{Timeout: 10 * time.Second},
		baseURL: openMeteoBaseURL,
		now:     time.Now,
	}
	for _, opt := range opts {
		opt(o)
	}
	return o
}

// WithLightningHTTPClient sets the HTTP client, mainly for tests.
func WithLightningHTTPClient(c *http.Client) OpenMeteoLightningOption {
	return func(o *OpenMeteoLightning) { o.client = c }
}

// WithLightningBaseURL overrides the endpoint, mainly for tests.
func WithLightningBaseURL(u string) OpenMeteoLightningOption {
	return func(o *OpenMeteoLightning) { o.baseURL = u }
}

// WithLightningClock overrides the clock, mainly for tests.
func WithLightningClock(now func() time.Time) OpenMeteoLightningOption {
	return func(o *OpenMeteoLightning) { o.now = now }
}

// Lightning fetches the hourly instability and thunderstorm codes and grades the
// near-term strike risk.
func (o *OpenMeteoLightning) Lightning(ctx context.Context, loc Location) (Lightning, error) {
	if err := validateLocation(loc); err != nil {
		return Lightning{}, err
	}
	endpoint, err := o.buildURL(loc)
	if err != nil {
		return Lightning{}, fmt.Errorf("%w: build url: %w", ErrProvider, err)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return Lightning{}, fmt.Errorf("%w: new request: %w", ErrProvider, err)
	}
	resp, err := o.client.Do(req)
	if err != nil {
		return Lightning{}, fmt.Errorf("%w: %w", ErrProvider, err)
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		return Lightning{}, fmt.Errorf("%w: status %d", ErrProvider, resp.StatusCode)
	}
	var raw openMeteoLightningResponse
	if err := json.NewDecoder(resp.Body).Decode(&raw); err != nil {
		return Lightning{}, fmt.Errorf("%w: decode: %w", ErrProvider, err)
	}
	return assessLightning(raw.hours(), o.now()), nil
}

// buildURL assembles the Open-Meteo request for storm-relevant hourly fields.
func (o *OpenMeteoLightning) buildURL(loc Location) (string, error) {
	u, err := url.Parse(o.baseURL)
	if err != nil {
		return "", err
	}
	q := url.Values{}
	q.Set("latitude", strconv.FormatFloat(loc.Lat, 'f', -1, 64))
	q.Set("longitude", strconv.FormatFloat(loc.Lon, 'f', -1, 64))
	q.Set("timeformat", "unixtime")
	q.Set("timezone", "auto")
	q.Set("forecast_days", "2")
	q.Set("hourly", strings.Join([]string{"weather_code", "cape", "lightning_potential"}, ","))
	u.RawQuery = q.Encode()
	return u.String(), nil
}

// openMeteoLightningResponse is the raw Open-Meteo response for storm fields.
type openMeteoLightningResponse struct {
	// Hourly holds the parallel storm arrays.
	Hourly openMeteoLightningHourly `json:"hourly"`
}

// openMeteoLightningHourly is the hourly block of the storm response. Lightning
// potential is a pointer since the global model leaves it null.
type openMeteoLightningHourly struct {
	// Time holds the hour-start epochs in seconds.
	Time []int64 `json:"time"`
	// WeatherCode holds hourly WMO weather codes.
	WeatherCode []int `json:"weather_code"`
	// Cape holds hourly convective available potential energy in J/kg.
	Cape []float64 `json:"cape"`
	// LightningPotential holds hourly lightning potential in J/kg, null globally.
	LightningPotential []*float64 `json:"lightning_potential"`
}

// lightningHour is one normalized hour of storm inputs.
type lightningHour struct {
	// time is the hour start in UTC.
	time time.Time
	// code is the WMO weather code.
	code int
	// cape is the convective energy in J/kg.
	cape float64
	// lp is the lightning potential in J/kg, zero when the model omits it.
	lp float64
}

// hours flattens the parallel arrays into normalized hours.
func (r openMeteoLightningResponse) hours() []lightningHour {
	out := make([]lightningHour, 0, len(r.Hourly.Time))
	for i, t := range r.Hourly.Time {
		var lp float64
		if p := at(r.Hourly.LightningPotential, i); p != nil {
			lp = *p
		}
		out = append(out, lightningHour{
			time: time.Unix(t, 0).UTC(),
			code: at(r.Hourly.WeatherCode, i),
			cape: at(r.Hourly.Cape, i),
			lp:   lp,
		})
	}
	return out
}

// isThunderCode reports whether a WMO code is a thunderstorm.
func isThunderCode(code int) bool {
	return code == wmoThunderstorm || code == wmoThunderHail || code == wmoThunderHeavy
}

// assessLightning grades strike risk from the coming hours. Forecast thunderstorm
// hours set the floor; CAPE and hail push it higher; high instability alone earns
// a low watch even with no coded storm.
func assessLightning(hours []lightningHour, now time.Time) Lightning {
	horizon := now.Add(lightningHorizon)
	var stormHours int
	var firstStorm time.Time
	var hasStorm, hasHail bool
	var stormCape, soonCape float64
	for _, h := range hours {
		if h.time.Before(now.Add(-30*time.Minute)) || h.time.After(horizon) {
			continue
		}
		if h.time.Before(now.Add(6 * time.Hour)) {
			soonCape = maxF(soonCape, h.cape)
		}
		if isThunderCode(h.code) {
			stormHours++
			if !hasStorm {
				firstStorm = h.time
				hasStorm = true
			}
			stormCape = maxF(stormCape, h.cape)
			if h.code == wmoThunderHail || h.code == wmoThunderHeavy {
				hasHail = true
			}
		}
	}

	if !hasStorm {
		if soonCape >= capeHigh {
			return Lightning{
				Risk: "low", Level: 1, PeakCapeJPerKg: soonCape,
				Headline: "The air is charged up. Pop-up storms are possible.",
			}
		}
		return Lightning{Risk: "none", Level: 0, PeakCapeJPerKg: soonCape,
			Headline: "Quiet skies, nothing sparking."}
	}

	level := 2
	if stormCape >= capeHigh || hasHail {
		level = 3
	}
	if stormCape >= capeExtreme || (hasHail && stormCape >= capeHigh) {
		level = 4
	}
	imminent := !firstStorm.Before(now.Add(-30*time.Minute)) && firstStorm.Before(now.Add(lightningImminent))
	return Lightning{
		Risk:           riskName(level),
		Level:          level,
		Imminent:       imminent,
		Next:           firstStorm,
		HasNext:        true,
		PeakCapeJPerKg: stormCape,
		StormHours:     stormHours,
		Headline:       lightningHeadline(level, imminent),
	}
}

// riskName maps a level to its band name.
func riskName(level int) string {
	switch level {
	case 1:
		return "low"
	case 2:
		return "moderate"
	case 3:
		return "high"
	case 4:
		return "extreme"
	default:
		return "none"
	}
}

// lightningHeadline is the bird's storm line for a level.
func lightningHeadline(level int, imminent bool) string {
	if imminent {
		return "Storm closing in. Get under cover before it hits."
	}
	switch level {
	case 2:
		return "Thunderstorms are in the cards. Keep an eye on the sky."
	case 3:
		return "Strong storms are brewing. Lightning is likely."
	case 4:
		return "Dangerous storms ahead. Be ready to take shelter."
	default:
		return "Storms are possible. Stay aware."
	}
}

// maxF returns the larger of two floats.
func maxF(a, b float64) float64 {
	if a > b {
		return a
	}
	return b
}
