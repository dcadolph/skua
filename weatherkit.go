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
	"sync"
	"time"
	"unicode"
)

// weatherKitBaseURL is the default Apple WeatherKit REST API host.
const weatherKitBaseURL = "https://weatherkit.apple.com"

// weatherKitSource is the source name stamped on forecasts from this provider.
const weatherKitSource = "weatherkit"

// WeatherKitProvider is a Provider backed by Apple WeatherKit's REST API.
type WeatherKitProvider struct {
	// key signs the bearer tokens the API requires.
	key *appleKey
	// client is the HTTP client used for requests.
	client *http.Client
	// baseURL is the API host, overridable for testing.
	baseURL string
	// now returns the current time and is overridable in tests.
	now func() time.Time
	// tokenTTL is how long a minted bearer token stays valid.
	tokenTTL time.Duration
	// mu guards the cached token.
	mu sync.Mutex
	// cachedToken is the current bearer token, reused until near expiry.
	cachedToken string
	// tokenExp is when the cached token expires.
	tokenExp time.Time
}

// WeatherKitOption configures a WeatherKitProvider.
type WeatherKitOption func(*WeatherKitProvider)

// NewWeatherKit builds a WeatherKitProvider from credentials and a signing key.
func NewWeatherKit(teamID, serviceID, keyID string, keyPEM []byte, opts ...WeatherKitOption) (*WeatherKitProvider, error) {
	key, err := parseAppleKey(teamID, serviceID, keyID, keyPEM)
	if err != nil {
		return nil, err
	}
	p := &WeatherKitProvider{
		key:      key,
		client:   &http.Client{Timeout: 10 * time.Second},
		baseURL:  weatherKitBaseURL,
		now:      time.Now,
		tokenTTL: time.Hour,
	}
	for _, opt := range opts {
		opt(p)
	}
	return p, nil
}

// WithWKHTTPClient sets the HTTP client, mainly for tests.
func WithWKHTTPClient(c *http.Client) WeatherKitOption {
	return func(p *WeatherKitProvider) { p.client = c }
}

// WithWKBaseURL overrides the API host, mainly for tests.
func WithWKBaseURL(u string) WeatherKitOption {
	return func(p *WeatherKitProvider) { p.baseURL = u }
}

// Forecast fetches and normalizes the WeatherKit forecast for loc.
func (p *WeatherKitProvider) Forecast(ctx context.Context, loc Location) (Forecast, error) {
	if err := validateLocation(loc); err != nil {
		return Forecast{}, err
	}
	tok, err := p.bearer()
	if err != nil {
		return Forecast{}, fmt.Errorf("%w: token: %w", ErrProvider, err)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, p.buildURL(loc), nil)
	if err != nil {
		return Forecast{}, fmt.Errorf("%w: new request: %w", ErrProvider, err)
	}
	req.Header.Set("Authorization", "Bearer "+tok)
	resp, err := p.client.Do(req)
	if err != nil {
		return Forecast{}, fmt.Errorf("%w: %w", ErrProvider, err)
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		return Forecast{}, fmt.Errorf("%w: status %d", ErrProvider, resp.StatusCode)
	}
	var raw wkResponse
	if err := json.NewDecoder(resp.Body).Decode(&raw); err != nil {
		return Forecast{}, fmt.Errorf("%w: decode: %w", ErrProvider, err)
	}
	return raw.normalize(loc), nil
}

// bearer returns a cached token when it is still fresh, otherwise mints a new
// one. Minting is cheap, but reuse avoids signing on every request.
func (p *WeatherKitProvider) bearer() (string, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	now := p.now()
	if p.cachedToken != "" && now.Before(p.tokenExp.Add(-5*time.Minute)) {
		return p.cachedToken, nil
	}
	tok, err := p.key.token(now, p.tokenTTL)
	if err != nil {
		return "", err
	}
	p.cachedToken = tok
	p.tokenExp = now.Add(p.tokenTTL)
	return tok, nil
}

// buildURL assembles the WeatherKit request URL for loc.
func (p *WeatherKitProvider) buildURL(loc Location) string {
	q := url.Values{}
	q.Set("dataSets", "currentWeather,forecastDaily,forecastHourly")
	q.Set("timezone", "UTC")
	return fmt.Sprintf("%s/api/v1/weather/en/%s/%s?%s",
		p.baseURL,
		strconv.FormatFloat(loc.Lat, 'f', -1, 64),
		strconv.FormatFloat(loc.Lon, 'f', -1, 64),
		q.Encode())
}

// wkResponse is the raw JSON returned by the WeatherKit weather endpoint.
type wkResponse struct {
	// CurrentWeather is the present-conditions block.
	CurrentWeather wkCurrent `json:"currentWeather"`
	// ForecastHourly holds the hourly forecast block.
	ForecastHourly wkHourly `json:"forecastHourly"`
	// ForecastDaily holds the daily forecast block.
	ForecastDaily wkDaily `json:"forecastDaily"`
}

// wkCurrent is the current-weather block of a WeatherKit response.
type wkCurrent struct {
	// AsOf is the observation time.
	AsOf time.Time `json:"asOf"`
	// ConditionCode is the WeatherKit condition enum.
	ConditionCode string `json:"conditionCode"`
	// Temperature is the air temperature in Celsius.
	Temperature float64 `json:"temperature"`
	// TemperatureApparent is the feels-like temperature in Celsius.
	TemperatureApparent float64 `json:"temperatureApparent"`
	// Humidity is the relative humidity as a fraction from 0 to 1.
	Humidity float64 `json:"humidity"`
	// PrecipitationIntensity is the current precipitation rate in mm per hour.
	PrecipitationIntensity float64 `json:"precipitationIntensity"`
	// WindSpeed is the wind speed in kilometers per hour.
	WindSpeed float64 `json:"windSpeed"`
	// WindDirection is the wind direction in degrees.
	WindDirection float64 `json:"windDirection"`
	// UVIndex is the current UV index.
	UVIndex float64 `json:"uvIndex"`
	// Pressure is the sea-level pressure in millibars (equal to hectopascals).
	Pressure float64 `json:"pressure"`
	// TemperatureDewPoint is the dew point in Celsius.
	TemperatureDewPoint float64 `json:"temperatureDewPoint"`
	// Visibility is the visibility in meters.
	Visibility float64 `json:"visibility"`
	// WindGust is the wind gust speed in kilometers per hour.
	WindGust float64 `json:"windGust"`
	// CloudCover is the cloud cover as a fraction from 0 to 1.
	CloudCover float64 `json:"cloudCover"`
	// Daylight reports whether it is currently daytime.
	Daylight bool `json:"daylight"`
}

// wkHourly is the hourly forecast block of a WeatherKit response.
type wkHourly struct {
	// Hours holds the per-hour forecasts.
	Hours []wkHour `json:"hours"`
}

// wkHour is a single hour of a WeatherKit hourly forecast.
type wkHour struct {
	// ForecastStart is the start of the hour.
	ForecastStart time.Time `json:"forecastStart"`
	// ConditionCode is the WeatherKit condition enum.
	ConditionCode string `json:"conditionCode"`
	// Temperature is the air temperature in Celsius.
	Temperature float64 `json:"temperature"`
	// PrecipitationChance is the probability of precipitation from 0 to 1.
	PrecipitationChance float64 `json:"precipitationChance"`
	// PrecipitationAmount is the expected precipitation in millimeters.
	PrecipitationAmount float64 `json:"precipitationAmount"`
	// WindSpeed is the wind speed in kilometers per hour.
	WindSpeed float64 `json:"windSpeed"`
}

// wkDaily is the daily forecast block of a WeatherKit response.
type wkDaily struct {
	// Days holds the per-day forecasts.
	Days []wkDay `json:"days"`
}

// wkDay is a single day of a WeatherKit daily forecast.
type wkDay struct {
	// ForecastStart is the start of the day.
	ForecastStart time.Time `json:"forecastStart"`
	// Sunrise is the sunrise time.
	Sunrise time.Time `json:"sunrise"`
	// Sunset is the sunset time.
	Sunset time.Time `json:"sunset"`
	// ConditionCode is the WeatherKit condition enum.
	ConditionCode string `json:"conditionCode"`
	// TemperatureMax is the daytime high in Celsius.
	TemperatureMax float64 `json:"temperatureMax"`
	// TemperatureMin is the overnight low in Celsius.
	TemperatureMin float64 `json:"temperatureMin"`
	// PrecipitationChance is the probability of precipitation from 0 to 1.
	PrecipitationChance float64 `json:"precipitationChance"`
	// MaxUvIndex is the peak UV index for the day.
	MaxUvIndex float64 `json:"maxUvIndex"`
}

// normalize converts a raw WeatherKit response into a Forecast.
func (r wkResponse) normalize(loc Location) Forecast {
	c := r.CurrentWeather
	f := Forecast{
		Source:   weatherKitSource,
		Location: loc,
		Moon:     moonAt(c.AsOf.UTC()),
		Current: Current{
			Time:          c.AsOf.UTC(),
			Condition:     humanizeCondition(c.ConditionCode),
			TempC:         c.Temperature,
			ApparentTempC: c.TemperatureApparent,
			PrecipMM:      c.PrecipitationIntensity,
			WindKph:       c.WindSpeed,
			Humidity:      pct(c.Humidity),
			WindDirDeg:    int(math.Round(c.WindDirection)),
			UVIndex:       c.UVIndex,
			PressureHPa:   c.Pressure,
			DewPointC:     c.TemperatureDewPoint,
			VisibilityKm:  c.Visibility / 1000,
			WindGustKph:   c.WindGust,
			CloudCover:    pct(c.CloudCover),
			IsDay:         c.Daylight,
		},
	}
	for _, h := range r.ForecastHourly.Hours {
		f.Hourly = append(f.Hourly, HourlyPoint{
			Time:       h.ForecastStart.UTC(),
			Condition:  humanizeCondition(h.ConditionCode),
			TempC:      h.Temperature,
			PrecipMM:   h.PrecipitationAmount,
			WindKph:    h.WindSpeed,
			PrecipProb: pct(h.PrecipitationChance),
		})
	}
	for _, d := range r.ForecastDaily.Days {
		f.Daily = append(f.Daily, DailyPoint{
			Date:       d.ForecastStart.UTC(),
			Sunrise:    d.Sunrise.UTC(),
			Sunset:     d.Sunset.UTC(),
			Condition:  humanizeCondition(d.ConditionCode),
			HighC:      d.TemperatureMax,
			LowC:       d.TemperatureMin,
			UVIndexMax: d.MaxUvIndex,
			PrecipProb: pct(d.PrecipitationChance),
		})
	}
	return f
}

// pct converts a 0-to-1 fraction to a rounded 0-to-100 percentage.
func pct(frac float64) int {
	return int(math.Round(frac * 100))
}

// humanizeCondition turns a WeatherKit condition code like "MostlyCloudy" into
// a readable "Mostly Cloudy", or "Unknown" when the code is empty.
func humanizeCondition(code string) string {
	if code == "" {
		return "Unknown"
	}
	runes := []rune(code)
	var b strings.Builder
	for i, r := range runes {
		if i > 0 && unicode.IsUpper(r) && unicode.IsLower(runes[i-1]) {
			b.WriteRune(' ')
		}
		b.WriteRune(r)
	}
	return b.String()
}
