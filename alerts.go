package skua

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"sort"
	"time"
)

// nwsBaseURL is the National Weather Service API root.
const nwsBaseURL = "https://api.weather.gov"

// nwsUserAgent identifies Skua to the NWS API, as its terms require.
const nwsUserAgent = "skua (skuaweather.com, hello@skuaweather.com)"

// Alert is one active weather alert for a location.
type Alert struct {
	// Event is the alert type, such as Flood Warning.
	Event string `json:"event"`
	// Headline is the issuing office's one-line summary.
	Headline string `json:"headline"`
	// Severity is the NWS severity band: Extreme, Severe, Moderate, Minor, or
	// Unknown.
	Severity string `json:"severity"`
	// Urgency is the NWS urgency band, such as Immediate.
	Urgency string `json:"urgency"`
	// Area is the affected area description.
	Area string `json:"area"`
	// Onset is when the hazard begins, zero when unstated.
	Onset time.Time `json:"onset"`
	// Ends is when the hazard ends, falling back to the alert expiry, zero when
	// neither is stated.
	Ends time.Time `json:"ends"`
	// Description is the full alert text.
	Description string `json:"description"`
	// Instruction is the recommended action, empty when none is given.
	Instruction string `json:"instruction"`
}

// Alerts is the set of active alerts for a location, most severe first.
type Alerts struct {
	// Alerts holds the active alerts, empty when there are none.
	Alerts []Alert `json:"alerts"`
}

// AlertsProvider fetches active weather alerts for a location.
type AlertsProvider interface {
	// Alerts returns the active alerts for loc.
	Alerts(ctx context.Context, loc Location) (Alerts, error)
}

// AlertsProviderFunc adapts an ordinary function to an AlertsProvider.
type AlertsProviderFunc func(ctx context.Context, loc Location) (Alerts, error)

// Alerts calls f.
func (f AlertsProviderFunc) Alerts(ctx context.Context, loc Location) (Alerts, error) {
	return f(ctx, loc)
}

// NWSAlerts is an AlertsProvider backed by the free National Weather Service
// API. It covers the United States; other regions report no alerts.
type NWSAlerts struct {
	// client is the HTTP client used for requests.
	client *http.Client
	// baseURL is the API root, overridable for testing.
	baseURL string
}

// NWSAlertsOption configures an NWSAlerts provider.
type NWSAlertsOption func(*NWSAlerts)

// NewNWSAlerts builds an NWSAlerts provider with sensible defaults.
func NewNWSAlerts(opts ...NWSAlertsOption) *NWSAlerts {
	o := &NWSAlerts{
		client:  &http.Client{Timeout: 10 * time.Second},
		baseURL: nwsBaseURL,
	}
	for _, opt := range opts {
		opt(o)
	}
	return o
}

// WithAlertsHTTPClient sets the HTTP client, mainly for tests.
func WithAlertsHTTPClient(c *http.Client) NWSAlertsOption {
	return func(o *NWSAlerts) { o.client = c }
}

// WithAlertsBaseURL overrides the API root, mainly for tests.
func WithAlertsBaseURL(u string) NWSAlertsOption {
	return func(o *NWSAlerts) { o.baseURL = u }
}

// nwsAlertsResponse is the raw GeoJSON returned by the NWS active-alerts query.
type nwsAlertsResponse struct {
	// Features holds one entry per active alert.
	Features []struct {
		// Properties carries the alert fields.
		Properties struct {
			// Event is the alert type.
			Event string `json:"event"`
			// Headline is the one-line summary.
			Headline string `json:"headline"`
			// Severity is the severity band.
			Severity string `json:"severity"`
			// Urgency is the urgency band.
			Urgency string `json:"urgency"`
			// AreaDesc is the affected area description.
			AreaDesc string `json:"areaDesc"`
			// Onset is the hazard start time.
			Onset string `json:"onset"`
			// Ends is the hazard end time, often null.
			Ends string `json:"ends"`
			// Expires is the alert expiry time.
			Expires string `json:"expires"`
			// Description is the full alert text.
			Description string `json:"description"`
			// Instruction is the recommended action.
			Instruction string `json:"instruction"`
		} `json:"properties"`
	} `json:"features"`
}

// Alerts fetches the active NWS alerts for loc, most severe first. Points the
// NWS does not cover return no alerts rather than an error.
func (o *NWSAlerts) Alerts(ctx context.Context, loc Location) (Alerts, error) {
	if err := validateLocation(loc); err != nil {
		return Alerts{}, err
	}
	endpoint := fmt.Sprintf("%s/alerts/active?point=%.4f,%.4f", o.baseURL, loc.Lat, loc.Lon)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return Alerts{}, fmt.Errorf("%w: new request: %w", ErrProvider, err)
	}
	req.Header.Set("User-Agent", nwsUserAgent)
	req.Header.Set("Accept", "application/geo+json")
	resp, err := o.client.Do(req)
	if err != nil {
		return Alerts{}, fmt.Errorf("%w: %w", ErrProvider, err)
	}
	defer func() { _ = resp.Body.Close() }()
	// The NWS rejects points outside its coverage with a 400. That is simply a
	// place with no NWS alerts, not a failure.
	if resp.StatusCode == http.StatusBadRequest {
		return Alerts{Alerts: []Alert{}}, nil
	}
	if resp.StatusCode != http.StatusOK {
		return Alerts{}, fmt.Errorf("%w: status %d", ErrProvider, resp.StatusCode)
	}
	var raw nwsAlertsResponse
	if err := json.NewDecoder(resp.Body).Decode(&raw); err != nil {
		return Alerts{}, fmt.Errorf("%w: decode: %w", ErrProvider, err)
	}
	return raw.normalize(), nil
}

// normalize converts the raw GeoJSON into Alerts sorted most severe first.
func (r nwsAlertsResponse) normalize() Alerts {
	out := Alerts{Alerts: make([]Alert, 0, len(r.Features))}
	for _, f := range r.Features {
		p := f.Properties
		ends := parseAlertTime(p.Ends)
		if ends.IsZero() {
			ends = parseAlertTime(p.Expires)
		}
		out.Alerts = append(out.Alerts, Alert{
			Event:       p.Event,
			Headline:    p.Headline,
			Severity:    p.Severity,
			Urgency:     p.Urgency,
			Area:        p.AreaDesc,
			Onset:       parseAlertTime(p.Onset),
			Ends:        ends,
			Description: p.Description,
			Instruction: p.Instruction,
		})
	}
	sort.SliceStable(out.Alerts, func(i, j int) bool {
		return severityRank(out.Alerts[i].Severity) < severityRank(out.Alerts[j].Severity)
	})
	return out
}

// severityRank orders NWS severity bands, most severe first.
func severityRank(s string) int {
	switch s {
	case "Extreme":
		return 0
	case "Severe":
		return 1
	case "Moderate":
		return 2
	case "Minor":
		return 3
	default:
		return 4
	}
}

// parseAlertTime parses an NWS timestamp, returning the zero time for empty or
// malformed values.
func parseAlertTime(s string) time.Time {
	if s == "" {
		return time.Time{}
	}
	t, err := time.Parse(time.RFC3339, s)
	if err != nil {
		return time.Time{}
	}
	return t.UTC()
}
