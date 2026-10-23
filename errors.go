package skua

import "errors"

// ErrProvider is returned when a weather provider fails to produce a forecast.
var ErrProvider = errors.New("provider")

// ErrLocation is returned when a requested location is invalid.
var ErrLocation = errors.New("invalid location")

// ErrConfig is returned when provider configuration is invalid.
var ErrConfig = errors.New("configuration")

// ErrVoice is returned when the AI voice fails to produce a line.
var ErrVoice = errors.New("voice")
