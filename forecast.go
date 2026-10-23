package skua

import (
	"fmt"
	"time"
)

// Location is a geographic coordinate a forecast is requested for.
type Location struct {
	// Lat is the latitude in decimal degrees.
	Lat float64 `json:"lat"`
	// Lon is the longitude in decimal degrees.
	Lon float64 `json:"lon"`
}

// Forecast is the normalized weather result assembled from a provider.
type Forecast struct {
	// Source names the provider that produced the forecast.
	Source string `json:"source"`
	// Location is the coordinate the forecast covers.
	Location Location `json:"location"`
	// Moon is the current lunar phase, computed rather than fetched.
	Moon Moon `json:"moon"`
	// Yesterday is the prior day's outcome for comparison, nil when the
	// provider has none.
	Yesterday *DailyPoint `json:"yesterday,omitempty"`
	// Current is the present conditions.
	Current Current `json:"current"`
	// Minutely holds fine-grained near-term precipitation points in
	// chronological order, empty when the provider has none.
	Minutely []MinutelyPoint `json:"minutely,omitempty"`
	// Hourly holds the near-term hourly points in chronological order.
	Hourly []HourlyPoint `json:"hourly"`
	// Daily holds the multi-day points in chronological order.
	Daily []DailyPoint `json:"daily"`
}

// Current holds present weather conditions.
type Current struct {
	// Time is the observation time in UTC.
	Time time.Time `json:"time"`
	// Condition is the human-readable sky condition.
	Condition string `json:"condition"`
	// TempC is the air temperature in Celsius.
	TempC float64 `json:"tempC"`
	// ApparentTempC is the feels-like temperature in Celsius.
	ApparentTempC float64 `json:"apparentTempC"`
	// PrecipMM is the precipitation for the current interval in millimeters.
	PrecipMM float64 `json:"precipMM"`
	// WindKph is the wind speed in kilometers per hour.
	WindKph float64 `json:"windKph"`
	// Humidity is the relative humidity as a percentage from 0 to 100.
	Humidity int `json:"humidity"`
	// WindDirDeg is the wind direction in degrees clockwise from north.
	WindDirDeg int `json:"windDirDeg"`
	// UVIndex is the current UV index.
	UVIndex float64 `json:"uvIndex"`
	// PressureHPa is the surface pressure in hectopascals.
	PressureHPa float64 `json:"pressureHPa"`
	// DewPointC is the dew point in Celsius.
	DewPointC float64 `json:"dewPointC"`
	// VisibilityKm is the visibility in kilometers.
	VisibilityKm float64 `json:"visibilityKm"`
	// WindGustKph is the wind gust speed in kilometers per hour.
	WindGustKph float64 `json:"windGustKph"`
	// CloudCover is the cloud cover as a percentage from 0 to 100.
	CloudCover int `json:"cloudCover"`
	// IsDay reports whether it is currently daytime.
	IsDay bool `json:"isDay"`
}

// MinutelyPoint is expected precipitation for one short interval, used for the
// rain-soon call.
type MinutelyPoint struct {
	// Time is the start of the interval in UTC.
	Time time.Time `json:"time"`
	// PrecipMM is the expected precipitation for the interval in millimeters.
	PrecipMM float64 `json:"precipMM"`
}

// HourlyPoint is the forecast for a single hour, carrying every series the
// clients can graph.
type HourlyPoint struct {
	// Time is the start of the hour in UTC.
	Time time.Time `json:"time"`
	// Condition is the human-readable sky condition.
	Condition string `json:"condition"`
	// TempC is the air temperature in Celsius.
	TempC float64 `json:"tempC"`
	// ApparentTempC is the feels-like temperature in Celsius.
	ApparentTempC float64 `json:"apparentTempC"`
	// PrecipMM is the expected precipitation in millimeters.
	PrecipMM float64 `json:"precipMM"`
	// WindKph is the wind speed in kilometers per hour.
	WindKph float64 `json:"windKph"`
	// WindGustKph is the wind gust speed in kilometers per hour.
	WindGustKph float64 `json:"windGustKph"`
	// Humidity is the relative humidity as a percentage.
	Humidity int `json:"humidity"`
	// PressureHPa is the surface pressure in hectopascals.
	PressureHPa float64 `json:"pressureHPa"`
	// DewPointC is the dew point in Celsius.
	DewPointC float64 `json:"dewPointC"`
	// CloudCover is the cloud cover as a percentage.
	CloudCover int `json:"cloudCover"`
	// UVIndex is the UV index.
	UVIndex float64 `json:"uvIndex"`
	// PrecipProb is the probability of precipitation as a percentage.
	PrecipProb int `json:"precipProb"`
}

// DailyPoint is the forecast for a single day.
type DailyPoint struct {
	// Date is the start of the day in UTC.
	Date time.Time `json:"date"`
	// Sunrise is the sunrise time in UTC.
	Sunrise time.Time `json:"sunrise"`
	// Sunset is the sunset time in UTC.
	Sunset time.Time `json:"sunset"`
	// Condition is the human-readable sky condition.
	Condition string `json:"condition"`
	// HighC is the daytime high in Celsius.
	HighC float64 `json:"highC"`
	// LowC is the overnight low in Celsius.
	LowC float64 `json:"lowC"`
	// ApparentHighC is the feels-like high in Celsius.
	ApparentHighC float64 `json:"apparentHighC"`
	// ApparentLowC is the feels-like low in Celsius.
	ApparentLowC float64 `json:"apparentLowC"`
	// UVIndexMax is the peak UV index for the day.
	UVIndexMax float64 `json:"uvIndexMax"`
	// PrecipSumMM is the total expected precipitation in millimeters.
	PrecipSumMM float64 `json:"precipSumMM"`
	// WindMaxKph is the peak sustained wind in kilometers per hour.
	WindMaxKph float64 `json:"windMaxKph"`
	// WindGustMaxKph is the peak gust in kilometers per hour.
	WindGustMaxKph float64 `json:"windGustMaxKph"`
	// DaylightSec is the length of daylight in seconds.
	DaylightSec float64 `json:"daylightSec"`
	// PrecipProb is the maximum probability of precipitation as a percentage.
	PrecipProb int `json:"precipProb"`
}

// validateLocation reports whether loc is a usable coordinate.
func validateLocation(loc Location) error {
	if loc.Lat < -90 || loc.Lat > 90 {
		return fmt.Errorf("%w: latitude %g out of range", ErrLocation, loc.Lat)
	}
	if loc.Lon < -180 || loc.Lon > 180 {
		return fmt.Errorf("%w: longitude %g out of range", ErrLocation, loc.Lon)
	}
	return nil
}
