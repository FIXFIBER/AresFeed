package routes

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/FIXFIBER/AresFeed/internal/config"
	"github.com/FIXFIBER/AresFeed/internal/database"
)

func TestFederationRoutesFollowFeatureFlag(t *testing.T) {
	pool := database.TestPool(t)
	request := func(enabled bool, target string) *httptest.ResponseRecorder {
		t.Helper()
		mux := http.NewServeMux()
		cfg := &config.Config{
			JWT:        config.JWTConfig{Secret: "test-secret"},
			Email:      config.EmailConfig{SiteURL: "https://AresFeed.example"},
			Federation: config.FederationConfig{Enabled: enabled},
		}
		Register(mux, pool, cfg)
		recorder := httptest.NewRecorder()
		mux.ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, target, nil))
		return recorder
	}

	if recorder := request(false, "/.well-known/webfinger"); recorder.Code != http.StatusNotFound {
		t.Fatalf("disabled WebFinger status=%d body=%s", recorder.Code, recorder.Body.String())
	}
	if recorder := request(true, "/.well-known/webfinger"); recorder.Code != http.StatusBadRequest {
		t.Fatalf("enabled WebFinger status=%d body=%s", recorder.Code, recorder.Body.String())
	}
	if recorder := request(false, "/api/v1/config"); recorder.Code != http.StatusOK || !strings.Contains(recorder.Body.String(), `"federation_enabled":false`) {
		t.Fatalf("public config status=%d body=%s", recorder.Code, recorder.Body.String())
	}
}
