package main

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	webpush "github.com/SherClockHolmes/webpush-go"
)

func TestIdentityRegistryValidation(t *testing.T) {
	t.Parallel()
	root := t.TempDir()
	validPath := filepath.Join(root, "valid.json")
	if err := os.WriteFile(validPath, []byte(`{
  "devices": {
    "louis-phone": {"user": "louis", "groups": ["family"]}
  }
}`), 0o600); err != nil {
		t.Fatal(err)
	}
	registry, err := loadIdentityRegistry(validPath)
	if err != nil || registry["louis-phone"].User != "louis" {
		t.Fatalf("valid identity registry was rejected: registry=%v err=%v", registry, err)
	}

	invalidPath := filepath.Join(root, "invalid.json")
	if err := os.WriteFile(invalidPath, []byte(`{
  "devices": {
    "phone": {"user": "louis", "groups": ["family", "family"]}
  }
}`), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := loadIdentityRegistry(invalidPath); err == nil {
		t.Fatal("duplicate identity groups were accepted")
	}
}

func TestHealthAuthenticationAndRemovedObjectAPI(t *testing.T) {
	t.Parallel()
	root := t.TempDir()
	tokenFile := filepath.Join(root, "tokens")
	if err := os.WriteFile(tokenFile, []byte("phone:secret-token\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	api := httptest.NewServer((&server{tokenFile: tokenFile}).routes())
	defer api.Close()

	response := request(t, api.Client(), http.MethodGet, api.URL+"/healthz", nil, nil)
	if response.StatusCode != http.StatusOK || !strings.Contains(readBody(t, response), `"protocol":1`) {
		t.Fatal("push gateway health response was invalid")
	}
	response = request(t, api.Client(), http.MethodGet, api.URL+"/v1/push/vapid", nil, nil)
	assertStatus(t, response, http.StatusUnauthorized)
	response = request(t, api.Client(), http.MethodGet, api.URL+"/v1/objects/vault/default/database", nil, map[string]string{
		"Authorization": "Bearer secret-token",
	})
	assertStatus(t, response, http.StatusNotFound)
}

func TestPushSubscriptionDeviceBindingAndInvalidation(t *testing.T) {
	t.Parallel()
	root := t.TempDir()
	tokenFile := filepath.Join(root, "tokens")
	internalTokenFile := filepath.Join(root, "internal-token")
	if err := os.WriteFile(tokenFile, []byte("phone:secret-token\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(internalTokenFile, []byte("hook-secret\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	privateKey, publicKey, err := webpush.GenerateVAPIDKeys()
	if err != nil {
		t.Fatal(err)
	}
	received := make(chan *http.Request, 1)
	pushTarget := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.Copy(io.Discard, r.Body)
		received <- r.Clone(r.Context())
		w.WriteHeader(http.StatusCreated)
	}))
	defer pushTarget.Close()
	endpointBase, err := url.Parse(pushTarget.URL)
	if err != nil {
		t.Fatal(err)
	}
	api := httptest.NewServer((&server{
		tokenFile: tokenFile,
		identities: map[string]identityRecord{
			"phone": {User: "louis", Groups: []string{"family"}},
		},
		internalToken: internalTokenFile,
		push: &pushPublisher{
			root: root, endpointBase: endpointBase,
			vapidPublic: publicKey, vapidPrivate: privateKey,
			vapidSubject: "mailto:test@example.invalid", httpClient: pushTarget.Client(),
		},
	}).routes())
	defer api.Close()

	response := request(t, api.Client(), http.MethodGet, api.URL+"/v1/push/vapid", nil, map[string]string{
		"Authorization": "Bearer secret-token",
	})
	if response.StatusCode != http.StatusOK || !strings.Contains(readBody(t, response), publicKey) {
		t.Fatal("VAPID key was not returned")
	}

	subscription, err := json.Marshal(map[string]any{
		"protocolVersion": invalidationProtocolVersion,
		"endpoint":        pushTarget.URL + "/upCapability?up=1",
		"p256dh":          publicKey,
		"auth":            "dGVzdC1hdXRoLXNlY3JldA",
		"temporary":       false,
	})
	if err != nil {
		t.Fatal(err)
	}
	response = request(t, api.Client(), http.MethodPut, api.URL+"/v1/push/subscriptions/other", subscription, map[string]string{
		"Authorization":       "Bearer secret-token",
		"X-Essentials-Device": "other",
	})
	assertStatus(t, response, http.StatusForbidden)
	response = request(t, api.Client(), http.MethodPut, api.URL+"/v1/push/subscriptions/phone", subscription, map[string]string{
		"Authorization":       "Bearer secret-token",
		"X-Essentials-Device": "phone",
	})
	assertStatus(t, response, http.StatusNoContent)

	response = request(t, api.Client(), http.MethodPost, api.URL+"/v1/push/invalidate/vault", nil, map[string]string{
		"Authorization":       "Bearer secret-token",
		"X-Essentials-Device": "other",
	})
	assertStatus(t, response, http.StatusForbidden)
	response = request(t, api.Client(), http.MethodPost, api.URL+"/v1/push/invalidate/vault", nil, map[string]string{
		"Authorization":       "Bearer secret-token",
		"X-Essentials-Device": "phone",
	})
	assertStatus(t, response, http.StatusAccepted)

	response = request(t, api.Client(), http.MethodPost, api.URL+"/internal/v1/invalidate", []byte(`{"protocolVersion":1,"namespace":"calendar"}`), map[string]string{
		"Authorization": "Bearer hook-secret",
		"Content-Type":  "application/json",
	})
	assertStatus(t, response, http.StatusAccepted)
	select {
	case pushed := <-received:
		if pushed.Header.Get("Content-Encoding") != "aes128gcm" || pushed.Header.Get("Authorization") == "" {
			t.Fatalf("missing Web Push headers: %v", pushed.Header)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("push invalidation was not published")
	}
}

func request(t *testing.T, client *http.Client, method, url string, body []byte, headers map[string]string) *http.Response {
	t.Helper()
	request, err := http.NewRequest(method, url, bytes.NewReader(body))
	if err != nil {
		t.Fatal(err)
	}
	for name, value := range headers {
		request.Header.Set(name, value)
	}
	response, err := client.Do(request)
	if err != nil {
		t.Fatal(err)
	}
	return response
}

func assertStatus(t *testing.T, response *http.Response, expected int) {
	t.Helper()
	defer response.Body.Close()
	if response.StatusCode != expected {
		body, _ := io.ReadAll(response.Body)
		t.Fatalf("expected %d, got %d: %s", expected, response.StatusCode, body)
	}
}

func readBody(t *testing.T, response *http.Response) string {
	t.Helper()
	defer response.Body.Close()
	body, err := io.ReadAll(response.Body)
	if err != nil {
		t.Fatal(err)
	}
	return string(body)
}
