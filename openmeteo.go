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

// openMeteoBaseURL is the default Open-Meteo forecast endpoint.
const openMeteoBaseURL = "https://api.open-meteo.com/v1/forecast"

// openMeteoSource is the source name stamped on forecasts from this provider.
const openMeteoSource = "open-meteo"

// OpenMeteo is a Provider backed by the free, key-less Open-Meteo API.
type OpenMeteo struct {
	// client is the HTTP client used for requests.
	client *http.Client
	// baseURL is the forecast endpoint, overridable for testing.
	baseURL string
	// forecastDays is the number of days to request.
	forecastDays int
}

// OpenMeteoOption configures an OpenMeteo provider.
type OpenMeteoOption func(*OpenMeteo)

// NewOpenMeteo builds an OpenMeteo provider with sensible defaults.
func NewOpenMeteo(opts ...OpenMeteoOption) *OpenMeteo {
	o := &OpenMeteo{
		client:       &http.Client{Timeout: 10 * time.Second},
		baseURL:      openMeteoBaseURL,
		forecastDays: 7,
	}
	for _, opt := range opts {
		opt(o)
	}
	return o
}

// WithHTTPClient sets the HTTP client, mainly for tests.
func WithHTTPClient(c *http.Client) OpenMeteoOption {
	return func(o *OpenMeteo) { o.client = c }
}

// WithBaseURL overrides the forecast endpoint, mainly for tests.
func WithBaseURL(u string) OpenMeteoOption {
	return func(o *OpenMeteo) { o.baseURL = u }
}

// Forecast fetches and normalizes the Open-Meteo forecast for loc.
func (o *OpenMeteo) Forecast(ctx context.Context, loc Location) (Forecast, error) {
	if err := validateLocation(loc); err != nil {
		return Forecast{}, err
	}
	endpoint, err := o.buildURL(loc)
	if err != nil {
		return Forecast{}, fmt.Errorf("%w: build url: %w", ErrProvider, err)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return Forecast{}, fmt.Errorf("%w: new request: %w", ErrProvider, err)
	}
	resp, err := o.client.Do(req)
	if err != nil {
		return Forecast{}, fmt.Errorf("%w: %w", ErrProvider, err)
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		return Forecast{}, fmt.Errorf("%w: status %d", ErrProvider, resp.StatusCode)
	}
	var raw openMeteoResponse
	if err := json.NewDecoder(resp.Body).Decode(&raw); err != nil {
		return Forecast{}, fmt.Errorf("%w: decode: %w", ErrProvider, err)
	}
	return raw.normalize(loc), nil
}

// buildURL assembles the Open-Meteo request URL for loc.
func (o *OpenMeteo) buildURL(loc Location) (string, error) {
	u, err := url.Parse(o.baseURL)
	if err != nil {
		return "", err
	}
	q := url.Values{}
	q.Set("latitude", strconv.FormatFloat(loc.Lat, 'f', -1, 64))
	q.Set("longitude", strconv.FormatFloat(loc.Lon, 'f', -1, 64))
	q.Set("timeformat", "unixtime")
	q.Set("timezone", "auto")
	q.Set("forecast_days", strconv.Itoa(o.forecastDays))
	q.Set("past_days", "1")
	q.Set("current", strings.Join([]string{
		"temperature_2m", "relative_humidity_2m", "apparent_temperature",
		"is_day", "precipitation", "weather_code", "wind_speed_10m", "wind_direction_10m",
		"uv_index", "surface_pressure", "dew_point_2m", "visibility", "cloud_cover", "wind_gusts_10m",
	}, ","))
	q.Set("minutely_15", "precipitation")
	q.Set("forecast_minutely_15", "8")
	q.Set("hourly", strings.Join([]string{
		"temperature_2m", "apparent_temperature", "precipitation_probability", "precipitation",
		"weather_code", "wind_speed_10m", "wind_gusts_10m", "relative_humidity_2m",
		"surface_pressure", "dew_point_2m", "cloud_cover", "uv_index",
	}, ","))
	q.Set("daily", strings.Join([]string{
		"weather_code", "temperature_2m_max", "temperature_2m_min",
		"apparent_temperature_max", "apparent_temperature_min",
		"precipitation_probability_max", "precipitation_sum", "uv_index_max",
		"wind_speed_10m_max", "wind_gusts_10m_max", "daylight_duration",
		"sunrise", "sunset",
	}, ","))
	u.RawQuery = q.Encode()
	return u.String(), nil
}

// openMeteoResponse is the raw JSON returned by the Open-Meteo forecast API.
type openMeteoResponse struct {
	// Current is the present-conditions block.
	Current openMeteoCurrent `json:"current"`
	// Minutely holds parallel arrays of 15-minute values.
	Minutely openMeteoMinutely `json:"minutely_15"`
	// Hourly holds parallel arrays of hourly values.
	Hourly openMeteoHourly `json:"hourly"`
	// Daily holds parallel arrays of daily values.
	Daily openMeteoDaily `json:"daily"`
}

// openMeteoCurrent is the current block of the Open-Meteo response.
type openMeteoCurrent struct {
	// Time is the observation epoch in seconds.
	Time int64 `json:"time"`
	// Temperature is the air temperature in Celsius.
	Temperature float64 `json:"temperature_2m"`
	// ApparentTemp is the feels-like temperature in Celsius.
	ApparentTemp float64 `json:"apparent_temperature"`
	// Precipitation is the current precipitation in millimeters.
	Precipitation float64 `json:"precipitation"`
	// WindSpeed is the wind speed in kilometers per hour.
	WindSpeed float64 `json:"wind_speed_10m"`
	// Humidity is the relative humidity percentage.
	Humidity int `json:"relative_humidity_2m"`
	// WeatherCode is the WMO weather code.
	WeatherCode int `json:"weather_code"`
	// WindDirection is the wind direction in degrees.
	WindDirection int `json:"wind_direction_10m"`
	// UVIndex is the current UV index.
	UVIndex float64 `json:"uv_index"`
	// Pressure is the surface pressure in hectopascals.
	Pressure float64 `json:"surface_pressure"`
	// DewPoint is the dew point in Celsius.
	DewPoint float64 `json:"dew_point_2m"`
	// Visibility is the visibility in meters.
	Visibility float64 `json:"visibility"`
	// WindGust is the wind gust speed in kilometers per hour.
	WindGust float64 `json:"wind_gusts_10m"`
	// CloudCover is the cloud cover percentage.
	CloudCover int `json:"cloud_cover"`
	// IsDay is 1 during daytime and 0 at night.
	IsDay int `json:"is_day"`
}

// openMeteoMinutely is the 15-minute block of the Open-Meteo response.
type openMeteoMinutely struct {
	// Time holds the interval-start epochs in seconds.
	Time []int64 `json:"time"`
	// Precipitation holds 15-minute precipitation in millimeters.
	Precipitation []float64 `json:"precipitation"`
}

// openMeteoHourly is the hourly block of the Open-Meteo response.
type openMeteoHourly struct {
	// Time holds the hour-start epochs in seconds.
	Time []int64 `json:"time"`
	// Temperature holds hourly air temperatures in Celsius.
	Temperature []float64 `json:"temperature_2m"`
	// ApparentTemp holds hourly feels-like temperatures in Celsius.
	ApparentTemp []float64 `json:"apparent_temperature"`
	// PrecipitationProbability holds hourly precipitation probabilities.
	PrecipitationProbability []int `json:"precipitation_probability"`
	// Precipitation holds hourly precipitation in millimeters.
	Precipitation []float64 `json:"precipitation"`
	// WeatherCode holds hourly WMO weather codes.
	WeatherCode []int `json:"weather_code"`
	// WindSpeed holds hourly wind speeds in kilometers per hour.
	WindSpeed []float64 `json:"wind_speed_10m"`
	// WindGusts holds hourly gust speeds in kilometers per hour.
	WindGusts []float64 `json:"wind_gusts_10m"`
	// Humidity holds hourly relative humidity percentages.
	Humidity []int `json:"relative_humidity_2m"`
	// Pressure holds hourly surface pressures in hectopascals.
	Pressure []float64 `json:"surface_pressure"`
	// DewPoint holds hourly dew points in Celsius.
	DewPoint []float64 `json:"dew_point_2m"`
	// CloudCover holds hourly cloud cover percentages.
	CloudCover []int `json:"cloud_cover"`
	// UVIndex holds hourly UV indices.
	UVIndex []float64 `json:"uv_index"`
}

// openMeteoDaily is the daily block of the Open-Meteo response.
type openMeteoDaily struct {
	// Time holds the day-start epochs in seconds.
	Time []int64 `json:"time"`
	// WeatherCode holds daily WMO weather codes.
	WeatherCode []int `json:"weather_code"`
	// TemperatureMax holds daily high temperatures in Celsius.
	TemperatureMax []float64 `json:"temperature_2m_max"`
	// TemperatureMin holds daily low temperatures in Celsius.
	TemperatureMin []float64 `json:"temperature_2m_min"`
	// ApparentMax holds daily feels-like highs in Celsius.
	ApparentMax []float64 `json:"apparent_temperature_max"`
	// ApparentMin holds daily feels-like lows in Celsius.
	ApparentMin []float64 `json:"apparent_temperature_min"`
	// PrecipitationProbabilityMax holds daily peak precipitation probabilities.
	PrecipitationProbabilityMax []int `json:"precipitation_probability_max"`
	// PrecipitationSum holds daily precipitation totals in millimeters.
	PrecipitationSum []float64 `json:"precipitation_sum"`
	// UVIndexMax holds daily peak UV indices.
	UVIndexMax []float64 `json:"uv_index_max"`
	// WindSpeedMax holds daily peak sustained winds in kilometers per hour.
	WindSpeedMax []float64 `json:"wind_speed_10m_max"`
	// WindGustsMax holds daily peak gusts in kilometers per hour.
	WindGustsMax []float64 `json:"wind_gusts_10m_max"`
	// DaylightDuration holds daylight lengths in seconds.
	DaylightDuration []float64 `json:"daylight_duration"`
	// Sunrise holds daily sunrise epochs in seconds.
	Sunrise []int64 `json:"sunrise"`
	// Sunset holds daily sunset epochs in seconds.
	Sunset []int64 `json:"sunset"`
}

// normalize converts a raw Open-Meteo response into a Forecast.
func (r openMeteoResponse) normalize(loc Location) Forecast {
	f := Forecast{
		Source:   openMeteoSource,
		Location: loc,
		Moon:     moonAt(time.Unix(r.Current.Time, 0).UTC()),
		Current: Current{
			Time:          time.Unix(r.Current.Time, 0).UTC(),
			Condition:     conditionForCode(r.Current.WeatherCode),
			TempC:         r.Current.Temperature,
			ApparentTempC: r.Current.ApparentTemp,
			PrecipMM:      r.Current.Precipitation,
			WindKph:       r.Current.WindSpeed,
			Humidity:      r.Current.Humidity,
			WindDirDeg:    r.Current.WindDirection,
			UVIndex:       r.Current.UVIndex,
			PressureHPa:   r.Current.Pressure,
			DewPointC:     r.Current.DewPoint,
			VisibilityKm:  r.Current.Visibility / 1000,
			WindGustKph:   r.Current.WindGust,
			CloudCover:    r.Current.CloudCover,
			IsDay:         r.Current.IsDay == 1,
		},
	}
	for i, t := range r.Minutely.Time {
		f.Minutely = append(f.Minutely, MinutelyPoint{
			Time:     time.Unix(t, 0).UTC(),
			PrecipMM: at(r.Minutely.Precipitation, i),
		})
	}
	for i, t := range r.Hourly.Time {
		f.Hourly = append(f.Hourly, HourlyPoint{
			Time:          time.Unix(t, 0).UTC(),
			Condition:     conditionForCode(at(r.Hourly.WeatherCode, i)),
			TempC:         at(r.Hourly.Temperature, i),
			ApparentTempC: at(r.Hourly.ApparentTemp, i),
			PrecipMM:      at(r.Hourly.Precipitation, i),
			WindKph:       at(r.Hourly.WindSpeed, i),
			WindGustKph:   at(r.Hourly.WindGusts, i),
			Humidity:      at(r.Hourly.Humidity, i),
			PressureHPa:   at(r.Hourly.Pressure, i),
			DewPointC:     at(r.Hourly.DewPoint, i),
			CloudCover:    at(r.Hourly.CloudCover, i),
			UVIndex:       at(r.Hourly.UVIndex, i),
			PrecipProb:    at(r.Hourly.PrecipitationProbability, i),
		})
	}
	for i, t := range r.Daily.Time {
		f.Daily = append(f.Daily, DailyPoint{
			Date:           time.Unix(t, 0).UTC(),
			Sunrise:        unixOrZero(at(r.Daily.Sunrise, i)),
			Sunset:         unixOrZero(at(r.Daily.Sunset, i)),
			Condition:      conditionForCode(at(r.Daily.WeatherCode, i)),
			HighC:          at(r.Daily.TemperatureMax, i),
			LowC:           at(r.Daily.TemperatureMin, i),
			ApparentHighC:  at(r.Daily.ApparentMax, i),
			ApparentLowC:   at(r.Daily.ApparentMin, i),
			UVIndexMax:     at(r.Daily.UVIndexMax, i),
			PrecipSumMM:    at(r.Daily.PrecipitationSum, i),
			WindMaxKph:     at(r.Daily.WindSpeedMax, i),
			WindGustMaxKph: at(r.Daily.WindGustsMax, i),
			DaylightSec:    at(r.Daily.DaylightDuration, i),
			PrecipProb:     at(r.Daily.PrecipitationProbabilityMax, i),
		})
	}
	// The response includes the past day for comparison. Peel rows that ended
	// more than a day before the observation into Yesterday, keeping Daily
	// anchored on today. Past hourly rows trim away the same way.
	for len(f.Daily) > 1 && f.Current.Time.Sub(f.Daily[0].Date) >= 24*time.Hour {
		y := f.Daily[0]
		f.Yesterday = &y
		f.Daily = f.Daily[1:]
	}
	for len(f.Hourly) > 0 && f.Current.Time.Sub(f.Hourly[0].Time) > time.Hour {
		f.Hourly = f.Hourly[1:]
	}
	return f
}

// at returns s[i], or the zero value when i is out of range. It guards against
// Open-Meteo omitting a field, which leaves its parallel array short or nil.
func at[T any](s []T, i int) T {
	if i >= 0 && i < len(s) {
		return s[i]
	}
	var zero T
	return zero
}

// unixOrZero converts an epoch in seconds to a UTC time, or the zero time when
// sec is zero.
func unixOrZero(sec int64) time.Time {
	if sec == 0 {
		return time.Time{}
	}
	return time.Unix(sec, 0).UTC()
}
