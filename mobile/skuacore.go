// Package skuacore exposes Skua's keyless weather aggregation as flat,
// gomobile-compatible functions. Each function takes primitive parameters,
// runs a provider on device with a bounded timeout, and returns the JSON
// encoding of the normalized result so a Swift caller can decode it directly.
package skuacore

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/dcadolph/skua"
)

// callTimeout bounds each on-device provider call so a slow network never
// hangs the caller.
const callTimeout = 12 * time.Second

// newContext returns a background context with the standard call timeout and
// its cancel function.
func newContext() (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), callTimeout)
}

// marshal encodes v as compact JSON and returns it as a string.
func marshal(v any) (string, error) {
	b, err := json.Marshal(v)
	if err != nil {
		return "", err
	}
	return string(b), nil
}

// Forecast returns the normalized forecast for the coordinate as JSON.
func Forecast(lat, lon float64) (string, error) {
	ctx, cancel := newContext()
	defer cancel()
	res, err := skua.NewOpenMeteo().Forecast(ctx, skua.Location{Lat: lat, Lon: lon})
	if err != nil {
		return "", err
	}
	return marshal(res)
}

// AirQuality returns current air quality for the coordinate as JSON.
func AirQuality(lat, lon float64) (string, error) {
	ctx, cancel := newContext()
	defer cancel()
	res, err := skua.NewOpenMeteoAir().AirQuality(ctx, skua.Location{Lat: lat, Lon: lon})
	if err != nil {
		return "", err
	}
	return marshal(res)
}

// Marine returns current coastal sea state for the coordinate as JSON.
func Marine(lat, lon float64) (string, error) {
	ctx, cancel := newContext()
	defer cancel()
	res, err := skua.NewOpenMeteoMarine().Marine(ctx, skua.Location{Lat: lat, Lon: lon})
	if err != nil {
		return "", err
	}
	return marshal(res)
}

// Aurora returns the current planetary Kp and aurora visibility for the
// coordinate as JSON.
func Aurora(lat, lon float64) (string, error) {
	ctx, cancel := newContext()
	defer cancel()
	res, err := skua.NewSWPCAurora().Aurora(ctx, skua.Location{Lat: lat, Lon: lon})
	if err != nil {
		return "", err
	}
	return marshal(res)
}

// Radar returns the current radar frame set as JSON. Radar is global, so it
// takes no coordinate.
func Radar() (string, error) {
	ctx, cancel := newContext()
	defer cancel()
	res, err := skua.NewRainViewer().Radar(ctx)
	if err != nil {
		return "", err
	}
	return marshal(res)
}

// Alerts returns the active weather alerts for the coordinate as JSON.
func Alerts(lat, lon float64) (string, error) {
	ctx, cancel := newContext()
	defer cancel()
	res, err := skua.NewNWSAlerts().Alerts(ctx, skua.Location{Lat: lat, Lon: lon})
	if err != nil {
		return "", err
	}
	return marshal(res)
}

// Tides returns coastal high and low water for the coordinate as JSON.
func Tides(lat, lon float64) (string, error) {
	ctx, cancel := newContext()
	defer cancel()
	res, err := skua.NewNOAATides().Tides(ctx, skua.Location{Lat: lat, Lon: lon})
	if err != nil {
		return "", err
	}
	return marshal(res)
}

// Lightning returns near-term storm and strike risk for the coordinate as JSON.
func Lightning(lat, lon float64) (string, error) {
	ctx, cancel := newContext()
	defer cancel()
	res, err := skua.NewOpenMeteoLightning().Lightning(ctx, skua.Location{Lat: lat, Lon: lon})
	if err != nil {
		return "", err
	}
	return marshal(res)
}

// Pollen returns current pollen conditions for the US ZIP code as JSON.
func Pollen(zip string) (string, error) {
	ctx, cancel := newContext()
	defer cancel()
	res, err := skua.NewCachingPollenProvider(skua.NewPollenDotCom()).Pollen(ctx, zip)
	if err != nil {
		return "", err
	}
	return marshal(res)
}

// Fact returns the fact of the day for the calendar date as JSON. Month and
// day are the one-based calendar month and day of month.
func Fact(month, day int) (string, error) {
	ctx, cancel := newContext()
	defer cancel()
	res, err := skua.NewCachingFactProvider(skua.NewWikipediaFacts()).Fact(ctx, month, day)
	if err != nil {
		return "", err
	}
	return marshal(res)
}

// decodeForecast unmarshals the forecast JSON the app is showing.
func decodeForecast(forecastJSON string) (skua.Forecast, error) {
	var fc skua.Forecast
	if err := json.Unmarshal([]byte(forecastJSON), &fc); err != nil {
		return skua.Forecast{}, fmt.Errorf("%w: decode forecast: %w", skua.ErrProvider, err)
	}
	return fc, nil
}

// Voice returns the skua's spoken line and briefing for the forecast as JSON.
// The forecast is the JSON the app is already showing, so the voice never
// disagrees with the screen. The level picks the maturity register and units of
// "imperial" speaks Fahrenheit and miles. It uses the built-in line bank, which
// needs no key and makes no network call.
func Voice(forecastJSON, level, units, eventTitle, eventWhen string, eventEpoch int64) (string, error) {
	fc, err := decodeForecast(forecastJSON)
	if err != nil {
		return "", err
	}
	opts := skua.VoiceOpts{
		Level:      skua.ParseVoiceLevel(level),
		EventTitle: eventTitle,
		EventWhen:  eventWhen,
		EventEpoch: eventEpoch,
		Imperial:   units == "imperial",
	}
	v, err := skua.NewTemplateVoicer().Speak(context.Background(), fc, opts)
	if err != nil {
		return "", err
	}
	return marshal(v)
}

// PartyVoice returns an occasion pack's line and briefing for the forecast as
// JSON. Occasion names the pack, heat sets how filthy it talks, and localHour is
// the listener's hour of day so the opener fits the stretch of the party. An
// unknown occasion falls back to the everyday voice at the dry level.
func PartyVoice(forecastJSON, occasion, heat, units string, localHour int,
	eventTitle, eventWhen string, eventEpoch int64) (string, error) {
	fc, err := decodeForecast(forecastJSON)
	if err != nil {
		return "", err
	}
	opts := skua.VoiceOpts{
		Level:      skua.DefaultVoiceLevel,
		EventTitle: eventTitle,
		EventWhen:  eventWhen,
		EventEpoch: eventEpoch,
		Imperial:   units == "imperial",
		Occasion:   skua.ParseOccasion(occasion),
		Heat:       skua.ParseHeat(heat),
		LocalHour:  localHour,
	}
	v, err := skua.NewTemplateVoicer().Speak(context.Background(), fc, opts)
	if err != nil {
		return "", err
	}
	return marshal(v)
}
