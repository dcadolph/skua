package skua

import "context"

// Provider fetches a normalized forecast for a location.
type Provider interface {
	// Forecast returns the normalized forecast for loc.
	Forecast(ctx context.Context, loc Location) (Forecast, error)
}

// ProviderFunc adapts an ordinary function to a Provider.
type ProviderFunc func(ctx context.Context, loc Location) (Forecast, error)

// Forecast calls f.
func (f ProviderFunc) Forecast(ctx context.Context, loc Location) (Forecast, error) {
	return f(ctx, loc)
}
