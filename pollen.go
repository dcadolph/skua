package skua

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

// pollenBaseURL is the default Pollen.com current pollen endpoint.
const pollenBaseURL = "https://www.pollen.com/api/forecast/current/pollen/"

// Pollen holds current and next-day pollen conditions for a US ZIP code.
type Pollen struct {
	// Date is the forecast date reported by the source.
	Date time.Time `json:"date"`
	// ZIP is the US ZIP code the forecast covers.
	ZIP string `json:"zip"`
	// City is the city name for the ZIP.
	City string `json:"city"`
	// State is the state abbreviation for the ZIP.
	State string `json:"state"`
	// Today is the pollen outlook for the current day.
	Today PollenDay `json:"today"`
	// Tomorrow is the pollen outlook for the next day.
	Tomorrow PollenDay `json:"tomorrow"`
}

// PollenDay is the pollen outlook for a single day.
type PollenDay struct {
	// Index is the pollen index on a 0 to 12 scale.
	Index float64 `json:"index"`
	// Category is the descriptive band for the index.
	Category string `json:"category"`
	// Triggers are the names of the top pollen sources for the day.
	Triggers []string `json:"triggers"`
}

// PollenProvider fetches current pollen conditions for a US ZIP code.
type PollenProvider interface {
	// Pollen returns the current pollen conditions for zip.
	Pollen(ctx context.Context, zip string) (Pollen, error)
}

// PollenProviderFunc adapts an ordinary function to a PollenProvider.
type PollenProviderFunc func(ctx context.Context, zip string) (Pollen, error)

// Pollen calls f.
func (f PollenProviderFunc) Pollen(ctx context.Context, zip string) (Pollen, error) {
	return f(ctx, zip)
}

// PollenDotCom is a PollenProvider backed by the free Pollen.com JSON endpoint.
type PollenDotCom struct {
	// client is the HTTP client used for requests.
	client *http.Client
	// baseURL is the pollen endpoint, overridable for testing.
	baseURL string
}

// PollenDotComOption configures a PollenDotCom provider.
type PollenDotComOption func(*PollenDotCom)

// NewPollenDotCom builds a PollenDotCom provider with sensible defaults.
func NewPollenDotCom(opts ...PollenDotComOption) *PollenDotCom {
	o := &PollenDotCom{
		client:  &http.Client{Timeout: 10 * time.Second},
		baseURL: pollenBaseURL,
	}
	for _, opt := range opts {
		opt(o)
	}
	return o
}

// WithPollenHTTPClient sets the HTTP client, mainly for tests.
func WithPollenHTTPClient(c *http.Client) PollenDotComOption {
	return func(o *PollenDotCom) { o.client = c }
}

// WithPollenBaseURL overrides the endpoint, mainly for tests.
func WithPollenBaseURL(u string) PollenDotComOption {
	return func(o *PollenDotCom) { o.baseURL = u }
}

// Pollen fetches and normalizes the Pollen.com forecast for zip.
func (o *PollenDotCom) Pollen(ctx context.Context, zip string) (Pollen, error) {
	if zip == "" {
		return Pollen{}, fmt.Errorf("%w: empty zip", ErrProvider)
	}
	endpoint := o.baseURL + zip
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return Pollen{}, fmt.Errorf("%w: new request: %w", ErrProvider, err)
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)")
	req.Header.Set("Referer", "https://www.pollen.com/forecast/current/pollen/"+zip)
	req.Header.Set("Accept", "application/json, text/plain, */*")
	resp, err := o.client.Do(req)
	if err != nil {
		return Pollen{}, fmt.Errorf("%w: %w", ErrProvider, err)
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		return Pollen{}, fmt.Errorf("%w: status %d", ErrProvider, resp.StatusCode)
	}
	var raw pollenDotComResponse
	if err := json.NewDecoder(resp.Body).Decode(&raw); err != nil {
		return Pollen{}, fmt.Errorf("%w: decode: %w", ErrProvider, err)
	}
	return raw.normalize(), nil
}

// pollenDotComResponse is the raw JSON returned by the Pollen.com endpoint.
type pollenDotComResponse struct {
	// ForecastDate is the date the forecast covers.
	ForecastDate time.Time `json:"ForecastDate"`
	// Location is the place and period data for the forecast.
	Location pollenDotComLocation `json:"Location"`
}

// pollenDotComLocation is the location block of a Pollen.com response.
type pollenDotComLocation struct {
	// ZIP is the US ZIP code the forecast covers.
	ZIP string `json:"ZIP"`
	// City is the city name for the ZIP.
	City string `json:"City"`
	// State is the state abbreviation for the ZIP.
	State string `json:"State"`
	// Periods are the per-day pollen outlooks.
	Periods []pollenDotComPeriod `json:"periods"`
}

// pollenDotComPeriod is a single day's outlook in a Pollen.com response.
type pollenDotComPeriod struct {
	// Type labels the period as Yesterday, Today, or Tomorrow.
	Type string `json:"Type"`
	// Index is the pollen index on a 0 to 12 scale.
	Index float64 `json:"Index"`
	// Triggers are the top pollen sources for the period.
	Triggers []pollenDotComTrigger `json:"Triggers"`
}

// pollenDotComTrigger is a single pollen source in a Pollen.com period.
type pollenDotComTrigger struct {
	// Name is the common name of the pollen source.
	Name string `json:"Name"`
	// Genus is the scientific genus of the pollen source.
	Genus string `json:"Genus"`
	// PlantType is the plant category of the pollen source.
	PlantType string `json:"PlantType"`
}

// normalize converts a raw Pollen.com response into a Pollen.
func (r pollenDotComResponse) normalize() Pollen {
	p := Pollen{
		Date:     r.ForecastDate,
		ZIP:      r.Location.ZIP,
		City:     r.Location.City,
		State:    r.Location.State,
		Today:    PollenDay{Triggers: []string{}},
		Tomorrow: PollenDay{Triggers: []string{}},
	}
	for _, period := range r.Location.Periods {
		switch period.Type {
		case "Today":
			p.Today = period.day()
		case "Tomorrow":
			p.Tomorrow = period.day()
		}
	}
	return p
}

// day converts a raw period into a PollenDay with a non-nil trigger slice.
func (p pollenDotComPeriod) day() PollenDay {
	triggers := make([]string, 0, len(p.Triggers))
	for _, t := range p.Triggers {
		triggers = append(triggers, t.Name)
	}
	return PollenDay{
		Index:    p.Index,
		Category: pollenCategory(p.Index),
		Triggers: triggers,
	}
}

// pollenCategory maps a pollen index to its descriptive band.
func pollenCategory(index float64) string {
	switch {
	case index < 2.5:
		return "Low"
	case index < 4.9:
		return "Low-Moderate"
	case index < 7.3:
		return "Moderate"
	case index < 9.7:
		return "High"
	default:
		return "Very High"
	}
}
