package skua

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"net/http"
	"net/url"
	"sort"
	"strconv"
	"sync"
	"time"
)

// noaaTideStationsURL is the NOAA CO-OPS station metadata endpoint. The
// tidepredictions filter returns every station that publishes tide predictions.
const noaaTideStationsURL = "https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations.json?type=tidepredictions"

// noaaTidePredictionsURL is the NOAA CO-OPS data endpoint for predictions.
const noaaTidePredictionsURL = "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter"

// tideApplication identifies Skua to the CO-OPS data API, as its terms request.
const tideApplication = "skua"

// tideStationMaxKM is how far a coast may be before tides are unavailable. Past
// this the nearest station's predictions no longer describe the local water.
const tideStationMaxKM = 60.0

// tideStationTTL is how long the fetched station list stays fresh. The catalog
// changes rarely, so this is measured in hours.
const tideStationTTL = 24 * time.Hour

// Tides holds today's high and low water for the coast nearest a location.
// Available is false for inland points with no station in range, which is how
// the client knows to hide the panel.
type Tides struct {
	// Available reports whether a tide station was found in range.
	Available bool `json:"available"`
	// StationID is the CO-OPS station identifier.
	StationID string `json:"stationId"`
	// StationName is the station's human name.
	StationName string `json:"stationName"`
	// State is the station's two-letter state, empty when unknown.
	State string `json:"state"`
	// DistanceKM is how far the station is from the requested point.
	DistanceKM float64 `json:"distanceKm"`
	// Datum is the vertical reference for the heights, MLLW.
	Datum string `json:"datum"`
	// Units is the height unit, feet.
	Units string `json:"units"`
	// Events are the high and low extremes in time order, spanning yesterday
	// through the day after tomorrow so the client can draw a curve around now.
	Events []TideEvent `json:"events"`
}

// TideEvent is a single high or low water extreme.
type TideEvent struct {
	// Time is the predicted time of the extreme in UTC.
	Time time.Time `json:"time"`
	// Type is either high or low.
	Type string `json:"type"`
	// HeightFt is the water height above the datum in feet.
	HeightFt float64 `json:"heightFt"`
}

// TidesProvider fetches high and low water for a location.
type TidesProvider interface {
	// Tides returns the nearest coast's tide extremes for loc.
	Tides(ctx context.Context, loc Location) (Tides, error)
}

// TidesProviderFunc adapts an ordinary function to a TidesProvider.
type TidesProviderFunc func(ctx context.Context, loc Location) (Tides, error)

// Tides calls f.
func (f TidesProviderFunc) Tides(ctx context.Context, loc Location) (Tides, error) {
	return f(ctx, loc)
}

// NOAATides is a TidesProvider backed by the free NOAA CO-OPS API. It caches the
// station catalog in memory and finds the nearest coast for each request.
type NOAATides struct {
	// client is the HTTP client used for requests.
	client *http.Client
	// stationsURL is the station metadata endpoint, overridable for testing.
	stationsURL string
	// predictURL is the predictions endpoint, overridable for testing.
	predictURL string
	// maxKM is the farthest a station may be before tides are unavailable.
	maxKM float64
	// stationTTL is how long the cached station list stays fresh.
	stationTTL time.Duration
	// now returns the current time and is overridable in tests.
	now func() time.Time
	// mu guards the station cache.
	mu sync.Mutex
	// stations is the cached station catalog, nil until first fetched.
	stations []tideStation
	// stationsExp is when the cached catalog stops being fresh.
	stationsExp time.Time
}

// NOAATidesOption configures a NOAATides provider.
type NOAATidesOption func(*NOAATides)

// NewNOAATides builds a NOAATides provider with sensible defaults.
func NewNOAATides(opts ...NOAATidesOption) *NOAATides {
	o := &NOAATides{
		client:      &http.Client{Timeout: 12 * time.Second},
		stationsURL: noaaTideStationsURL,
		predictURL:  noaaTidePredictionsURL,
		maxKM:       tideStationMaxKM,
		stationTTL:  tideStationTTL,
		now:         time.Now,
	}
	for _, opt := range opts {
		opt(o)
	}
	return o
}

// WithTidesHTTPClient sets the HTTP client, mainly for tests.
func WithTidesHTTPClient(c *http.Client) NOAATidesOption {
	return func(o *NOAATides) { o.client = c }
}

// WithTideStationsURL overrides the station metadata endpoint, mainly for tests.
func WithTideStationsURL(u string) NOAATidesOption {
	return func(o *NOAATides) { o.stationsURL = u }
}

// WithTidePredictionsURL overrides the predictions endpoint, mainly for tests.
func WithTidePredictionsURL(u string) NOAATidesOption {
	return func(o *NOAATides) { o.predictURL = u }
}

// WithTidesClock overrides the clock, mainly for tests.
func WithTidesClock(now func() time.Time) NOAATidesOption {
	return func(o *NOAATides) { o.now = now }
}

// WithTideMaxDistanceKM overrides the in-range distance, mainly for tests.
func WithTideMaxDistanceKM(km float64) NOAATidesOption {
	return func(o *NOAATides) { o.maxKM = km }
}

// Tides finds the nearest station and returns its high and low water. A location
// with no station in range returns an unavailable Tides, not an error.
func (o *NOAATides) Tides(ctx context.Context, loc Location) (Tides, error) {
	if err := validateLocation(loc); err != nil {
		return Tides{}, err
	}
	stations, err := o.loadStations(ctx)
	if err != nil {
		return Tides{}, fmt.Errorf("%w: stations: %w", ErrProvider, err)
	}
	station, distKM, ok := nearestTideStation(stations, loc, o.maxKM)
	if !ok {
		return Tides{Available: false, Events: []TideEvent{}}, nil
	}
	events, err := o.predictions(ctx, station.ID)
	if err != nil {
		return Tides{}, err
	}
	return Tides{
		Available:   true,
		StationID:   station.ID,
		StationName: station.Name,
		State:       station.State,
		DistanceKM:  math.Round(distKM*10) / 10,
		Datum:       "MLLW",
		Units:       "ft",
		Events:      events,
	}, nil
}

// loadStations returns the cached station catalog, fetching it on a cold or
// stale cache. A fetch failure with a warm-but-stale cache serves the stale copy
// rather than failing, since the catalog changes rarely.
func (o *NOAATides) loadStations(ctx context.Context) ([]tideStation, error) {
	o.mu.Lock()
	defer o.mu.Unlock()
	if o.stations != nil && o.now().Before(o.stationsExp) {
		return o.stations, nil
	}
	fetched, err := o.fetchStations(ctx)
	if err != nil {
		if o.stations != nil {
			return o.stations, nil
		}
		return nil, err
	}
	o.stations = fetched
	o.stationsExp = o.now().Add(o.stationTTL)
	return fetched, nil
}

// fetchStations pulls and normalizes the full CO-OPS station catalog.
func (o *NOAATides) fetchStations(ctx context.Context) ([]tideStation, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, o.stationsURL, nil)
	if err != nil {
		return nil, fmt.Errorf("new request: %w", err)
	}
	req.Header.Set("User-Agent", nwsUserAgent)
	resp, err := o.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("status %d", resp.StatusCode)
	}
	var raw noaaStationsResponse
	if err := json.NewDecoder(resp.Body).Decode(&raw); err != nil {
		return nil, fmt.Errorf("decode: %w", err)
	}
	out := make([]tideStation, 0, len(raw.Stations))
	for _, s := range raw.Stations {
		out = append(out, tideStation{
			ID:    s.ID,
			Name:  s.Name,
			State: s.State,
			Lat:   s.Lat,
			Lon:   s.Lng,
		})
	}
	return out, nil
}

// predictions fetches the high and low water extremes for a station across the
// window from yesterday through the day after tomorrow.
func (o *NOAATides) predictions(ctx context.Context, stationID string) ([]TideEvent, error) {
	endpoint, err := o.buildPredictionsURL(stationID)
	if err != nil {
		return nil, fmt.Errorf("%w: build url: %w", ErrProvider, err)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return nil, fmt.Errorf("%w: new request: %w", ErrProvider, err)
	}
	req.Header.Set("User-Agent", nwsUserAgent)
	resp, err := o.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("%w: %w", ErrProvider, err)
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("%w: predictions status %d", ErrProvider, resp.StatusCode)
	}
	var raw noaaPredictionsResponse
	if err := json.NewDecoder(resp.Body).Decode(&raw); err != nil {
		return nil, fmt.Errorf("%w: decode: %w", ErrProvider, err)
	}
	return raw.events()
}

// buildPredictionsURL assembles the datagetter request for a station's high and
// low water in GMT, so the client displays every time in the coast's own zone.
func (o *NOAATides) buildPredictionsURL(stationID string) (string, error) {
	u, err := url.Parse(o.predictURL)
	if err != nil {
		return "", err
	}
	now := o.now().UTC()
	q := url.Values{}
	q.Set("product", "predictions")
	q.Set("application", tideApplication)
	q.Set("begin_date", now.AddDate(0, 0, -1).Format("20060102"))
	q.Set("end_date", now.AddDate(0, 0, 2).Format("20060102"))
	q.Set("datum", "MLLW")
	q.Set("station", stationID)
	q.Set("time_zone", "gmt")
	q.Set("units", "english")
	q.Set("interval", "hilo")
	q.Set("format", "json")
	u.RawQuery = q.Encode()
	return u.String(), nil
}

// tideStation is a normalized CO-OPS tide station.
type tideStation struct {
	// ID is the CO-OPS station identifier.
	ID string
	// Name is the station's human name.
	Name string
	// State is the two-letter state, empty when unknown.
	State string
	// Lat is the station latitude in decimal degrees.
	Lat float64
	// Lon is the station longitude in decimal degrees.
	Lon float64
}

// noaaStationsResponse is the raw station catalog returned by the mdapi.
type noaaStationsResponse struct {
	// Stations is the list of tide prediction stations.
	Stations []noaaStation `json:"stations"`
}

// noaaStation is one raw station record. Longitude arrives as lng.
type noaaStation struct {
	// ID is the CO-OPS station identifier.
	ID string `json:"id"`
	// Name is the station's human name.
	Name string `json:"name"`
	// State is the two-letter state.
	State string `json:"state"`
	// Lat is the station latitude.
	Lat float64 `json:"lat"`
	// Lng is the station longitude.
	Lng float64 `json:"lng"`
}

// noaaPredictionsResponse is the raw datagetter response for hi and lo tides.
type noaaPredictionsResponse struct {
	// Predictions are the high and low water rows.
	Predictions []noaaPrediction `json:"predictions"`
	// Error carries a CO-OPS error message when the request could not be served.
	Error noaaTideError `json:"error"`
}

// noaaTideError is the error block CO-OPS returns in place of predictions.
type noaaTideError struct {
	// Message is the human-readable failure reason.
	Message string `json:"message"`
}

// noaaPrediction is one raw high or low water row. Height arrives as a string.
type noaaPrediction struct {
	// T is the local prediction time formatted as "2006-01-02 15:04".
	T string `json:"t"`
	// V is the water height as a decimal string.
	V string `json:"v"`
	// Type is H for high water or L for low water.
	Type string `json:"type"`
}

// events converts the raw prediction rows into sorted TideEvents. A CO-OPS error
// block becomes a provider error; unparseable rows are skipped.
func (r noaaPredictionsResponse) events() ([]TideEvent, error) {
	if r.Error.Message != "" {
		return nil, fmt.Errorf("%w: %s", ErrProvider, r.Error.Message)
	}
	out := make([]TideEvent, 0, len(r.Predictions))
	for _, p := range r.Predictions {
		t, err := time.Parse("2006-01-02 15:04", p.T)
		if err != nil {
			continue
		}
		height, err := strconv.ParseFloat(p.V, 64)
		if err != nil {
			continue
		}
		kind := "low"
		if p.Type == "H" {
			kind = "high"
		}
		out = append(out, TideEvent{Time: t.UTC(), Type: kind, HeightFt: height})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Time.Before(out[j].Time) })
	return out, nil
}

// nearestTideStation returns the closest station to loc within maxKM. The bool
// is false when the catalog is empty or the nearest station is out of range.
func nearestTideStation(stations []tideStation, loc Location, maxKM float64) (tideStation, float64, bool) {
	best := math.MaxFloat64
	var found tideStation
	ok := false
	for _, s := range stations {
		d := haversineKM(loc.Lat, loc.Lon, s.Lat, s.Lon)
		if d < best {
			best = d
			found = s
			ok = true
		}
	}
	if !ok || best > maxKM {
		return tideStation{}, 0, false
	}
	return found, best, true
}

// haversineKM returns the great-circle distance in kilometers between two points.
func haversineKM(lat1, lon1, lat2, lon2 float64) float64 {
	const earthRadiusKM = 6371.0
	const rad = math.Pi / 180
	dLat := (lat2 - lat1) * rad
	dLon := (lon2 - lon1) * rad
	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1*rad)*math.Cos(lat2*rad)*math.Sin(dLon/2)*math.Sin(dLon/2)
	return earthRadiusKM * 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
}
