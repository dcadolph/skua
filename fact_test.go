package skua

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/google/go-cmp/cmp"
	"github.com/google/go-cmp/cmp/cmpopts"
)

// wikipediaFactBody is a canned "on this day" response with three events.
const wikipediaFactBody = `{
  "selected": [
    {
      "text": "First event.",
      "year": 1901,
      "pages": [{"title": "First_Page", "normalizedtitle": "First Page"}]
    },
    {
      "text": "Second event.",
      "year": 1902,
      "pages": [{"title": "Second_Page", "normalizedtitle": "Second Page"}]
    },
    {
      "text": "Third event.",
      "year": 1903,
      "pages": [{"title": "Third_Page", "normalizedtitle": ""}]
    }
  ]
}`

// TestWikipediaFacts verifies deterministic event selection and field mapping.
func TestWikipediaFacts(t *testing.T) {
	t.Parallel()
	tests := []struct {
		WantFact Fact
		Month    int
		Day      int
	}{
		{ // Test 0: Day 1 selects the first event.
			Month: 9, Day: 1,
			WantFact: Fact{Year: 1901, Text: "First event.", Title: "First Page"},
		},
		{ // Test 1: Day 2 selects the second event.
			Month: 9, Day: 2,
			WantFact: Fact{Year: 1902, Text: "Second event.", Title: "Second Page"},
		},
		{ // Test 2: Day 3 selects the third event, title falls back to raw title.
			Month: 9, Day: 3,
			WantFact: Fact{Year: 1903, Text: "Third event.", Title: "Third Page"},
		},
		{ // Test 3: Day 4 wraps back to the first event.
			Month: 9, Day: 4,
			WantFact: Fact{Year: 1901, Text: "First event.", Title: "First Page"},
		},
	}
	for testNum, test := range tests {
		t.Run(fmt.Sprintf("test %d", testNum), func(t *testing.T) {
			t.Parallel()
			srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				if r.Header.Get("User-Agent") != factUserAgent {
					w.WriteHeader(http.StatusForbidden)
					return
				}
				_, _ = w.Write([]byte(wikipediaFactBody))
			}))
			defer srv.Close()
			p := NewWikipediaFacts(WithFactBaseURL(srv.URL + "/"))
			got, err := p.Fact(context.Background(), test.Month, test.Day)
			if err != nil {
				t.Fatalf("Fact: %v", err)
			}
			if diff := cmp.Diff(test.WantFact, got, cmpopts.EquateEmpty()); diff != "" {
				t.Errorf("fact mismatch (-want +got):\n%s", diff)
			}
		})
	}
}

// TestWikipediaFactsError covers non-200, empty selected, and invalid dates.
func TestWikipediaFactsError(t *testing.T) {
	t.Parallel()

	srv500 := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer srv500.Close()
	if _, err := NewWikipediaFacts(WithFactBaseURL(srv500.URL + "/")).Fact(context.Background(), 9, 9); !errors.Is(err, ErrProvider) {
		t.Errorf("non-200: want ErrProvider, got %v", err)
	}

	srvEmpty := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`{"selected": []}`))
	}))
	defer srvEmpty.Close()
	if _, err := NewWikipediaFacts(WithFactBaseURL(srvEmpty.URL + "/")).Fact(context.Background(), 9, 9); !errors.Is(err, ErrProvider) {
		t.Errorf("empty selected: want ErrProvider, got %v", err)
	}

	p := NewWikipediaFacts(WithFactBaseURL(srvEmpty.URL + "/"))
	if _, err := p.Fact(context.Background(), 0, 9); !errors.Is(err, ErrProvider) {
		t.Errorf("bad month: want ErrProvider, got %v", err)
	}
	if _, err := p.Fact(context.Background(), 9, 32); !errors.Is(err, ErrProvider) {
		t.Errorf("bad day: want ErrProvider, got %v", err)
	}
}
