package skua

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"
)

// factBaseURL is the default Wikipedia "On this day" selected-events endpoint.
const factBaseURL = "https://en.wikipedia.org/api/rest_v1/feed/onthisday/selected/"

// factUserAgent identifies the client, since Wikimedia blocks requests without
// a User-Agent header.
const factUserAgent = "SkuaWeather/1.0 (personal weather app)"

// Fact holds a single "on this day" historical event.
type Fact struct {
	// Year is the year the event occurred.
	Year int `json:"year"`
	// Text is the description of the event.
	Text string `json:"text"`
	// Title is the primary linked page's readable title, empty when none.
	Title string `json:"title"`
}

// FactProvider fetches a fact of the day for a calendar date.
type FactProvider interface {
	// Fact returns a fact for the given month and day.
	Fact(ctx context.Context, month, day int) (Fact, error)
}

// FactProviderFunc adapts an ordinary function to a FactProvider.
type FactProviderFunc func(ctx context.Context, month, day int) (Fact, error)

// Fact calls f.
func (f FactProviderFunc) Fact(ctx context.Context, month, day int) (Fact, error) {
	return f(ctx, month, day)
}

// WikipediaFacts is a FactProvider backed by the free Wikipedia "On this day" API.
type WikipediaFacts struct {
	// client is the HTTP client used for requests.
	client *http.Client
	// baseURL is the "on this day" endpoint, overridable for testing.
	baseURL string
}

// WikipediaFactsOption configures a WikipediaFacts provider.
type WikipediaFactsOption func(*WikipediaFacts)

// NewWikipediaFacts builds a WikipediaFacts provider with sensible defaults.
func NewWikipediaFacts(opts ...WikipediaFactsOption) *WikipediaFacts {
	o := &WikipediaFacts{
		client:  &http.Client{Timeout: 10 * time.Second},
		baseURL: factBaseURL,
	}
	for _, opt := range opts {
		opt(o)
	}
	return o
}

// WithFactHTTPClient sets the HTTP client, mainly for tests.
func WithFactHTTPClient(c *http.Client) WikipediaFactsOption {
	return func(o *WikipediaFacts) { o.client = c }
}

// WithFactBaseURL overrides the endpoint, mainly for tests.
func WithFactBaseURL(u string) WikipediaFactsOption {
	return func(o *WikipediaFacts) { o.baseURL = u }
}

// Fact fetches and normalizes the "on this day" facts for month and day.
func (o *WikipediaFacts) Fact(ctx context.Context, month, day int) (Fact, error) {
	if month < 1 || month > 12 {
		return Fact{}, fmt.Errorf("%w: month %d out of range", ErrProvider, month)
	}
	if day < 1 || day > 31 {
		return Fact{}, fmt.Errorf("%w: day %d out of range", ErrProvider, day)
	}
	endpoint := o.baseURL + fmt.Sprintf("%02d/%02d", month, day)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return Fact{}, fmt.Errorf("%w: new request: %w", ErrProvider, err)
	}
	req.Header.Set("User-Agent", factUserAgent)
	resp, err := o.client.Do(req)
	if err != nil {
		return Fact{}, fmt.Errorf("%w: %w", ErrProvider, err)
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		return Fact{}, fmt.Errorf("%w: status %d", ErrProvider, resp.StatusCode)
	}
	var raw wikipediaOnThisDayResponse
	if err := json.NewDecoder(resp.Body).Decode(&raw); err != nil {
		return Fact{}, fmt.Errorf("%w: decode: %w", ErrProvider, err)
	}
	return raw.normalize(month, day)
}

// wikipediaOnThisDayResponse is the raw JSON returned by the "on this day" API.
type wikipediaOnThisDayResponse struct {
	// Selected is the list of curated events for the date.
	Selected []wikipediaEvent `json:"selected"`
}

// wikipediaEvent is a single curated historical event.
type wikipediaEvent struct {
	// Text is the description of the event.
	Text string `json:"text"`
	// Year is the year the event occurred.
	Year int `json:"year"`
	// Pages is the list of linked Wikipedia pages for the event.
	Pages []wikipediaPage `json:"pages"`
}

// wikipediaPage is a Wikipedia page linked from an event.
type wikipediaPage struct {
	// Title is the raw page title with underscores for spaces.
	Title string `json:"title"`
	// NormalizedTitle is the readable page title.
	NormalizedTitle string `json:"normalizedtitle"`
}

// normalize converts a raw response into a single deterministic Fact. It picks
// one event by day so the choice is stable within a day but varies across days.
func (r wikipediaOnThisDayResponse) normalize(month, day int) (Fact, error) {
	if len(r.Selected) == 0 {
		return Fact{}, fmt.Errorf("%w: no events for %02d/%02d", ErrProvider, month, day)
	}
	event := r.Selected[(day-1)%len(r.Selected)]
	return Fact{
		Year:  event.Year,
		Text:  event.Text,
		Title: eventTitle(event),
	}, nil
}

// eventTitle returns the readable title of an event's primary page, falling
// back to the raw title with underscores replaced, and empty when no page.
func eventTitle(event wikipediaEvent) string {
	if len(event.Pages) == 0 {
		return ""
	}
	page := event.Pages[0]
	if page.NormalizedTitle != "" {
		return page.NormalizedTitle
	}
	return strings.ReplaceAll(page.Title, "_", " ")
}
