package main

import (
	"bufio"
	"context"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

var identifierPattern = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$`)

type authenticatedIdentity struct {
	Device string
	User   string
	Groups map[string]struct{}
}

type identityRecord struct {
	User   string   `json:"user"`
	Groups []string `json:"groups"`
}

type identityRegistry struct {
	Devices map[string]identityRecord `json:"devices"`
}

type server struct {
	tokenFile     string
	identities    map[string]identityRecord
	push          *pushPublisher
	internalToken string
}

func main() {
	listen := flag.String("listen", "127.0.0.1:8090", "HTTP listen address")
	data := flag.String("data", "/var/lib/essentials-push", "subscription directory")
	tokens := flag.String("token-file", "", "device token file")
	identitiesFile := flag.String("identity-file", "", "device identity registry")
	pushBase := flag.String("push-endpoint-base", "", "allowed UnifiedPush endpoint base URL")
	vapidPublic := flag.String("vapid-public-key-file", "", "VAPID public key file")
	vapidPrivate := flag.String("vapid-private-key-file", "", "VAPID private key file")
	vapidSubject := flag.String("vapid-subject", "", "VAPID subscriber contact")
	internalToken := flag.String("invalidation-token-file", "", "internal invalidation token file")
	flag.Parse()

	if *tokens == "" {
		log.Fatal("-token-file is required")
	}
	if err := os.MkdirAll(*data, 0o700); err != nil {
		log.Fatal(err)
	}
	identities, err := loadIdentityRegistry(*identitiesFile)
	if err != nil {
		log.Fatal(err)
	}
	push, err := newPushPublisher(*data, *pushBase, *vapidPublic, *vapidPrivate, *vapidSubject)
	if err != nil {
		log.Fatal(err)
	}
	handler := (&server{
		tokenFile:     *tokens,
		identities:    identities,
		push:          push,
		internalToken: *internalToken,
	}).routes()
	httpServer := &http.Server{
		Addr:              *listen,
		Handler:           handler,
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       90 * time.Second,
	}
	log.Printf("Essentials Push Gateway listening on %s", *listen)
	log.Fatal(httpServer.ListenAndServe())
}

func (s *server) routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]any{"status": "ok", "protocol": 1})
	})
	mux.Handle("/v1/push/", s.authenticate(http.HandlerFunc(s.handlePushAPI)))
	if s.push != nil && s.internalToken != "" {
		mux.Handle("POST /internal/v1/invalidate", s.authenticateInternal(http.HandlerFunc(s.handleInvalidation)))
	}
	return mux
}

func (s *server) handlePushAPI(w http.ResponseWriter, r *http.Request) {
	if s.push == nil {
		writeError(w, http.StatusNotFound, "Push is not configured")
		return
	}
	parts := strings.Split(strings.Trim(r.URL.Path, "/"), "/")
	identity := r.Context().Value(identityKey{}).(authenticatedIdentity)
	if len(parts) == 3 && parts[0] == "v1" && parts[1] == "push" && parts[2] == "vapid" {
		s.handleVAPID(w, r)
		return
	}
	if len(parts) == 4 && parts[0] == "v1" && parts[1] == "push" && parts[2] == "subscriptions" {
		if !identifierPattern.MatchString(parts[3]) {
			writeError(w, http.StatusBadRequest, "Invalid device identifier")
			return
		}
		s.handlePushSubscription(w, r, identity, parts[3])
		return
	}
	if len(parts) == 4 && parts[0] == "v1" && parts[1] == "push" && parts[2] == "invalidate" {
		if r.Method != http.MethodPost || !identifierPattern.MatchString(parts[3]) {
			writeError(w, http.StatusBadRequest, "Invalid invalidation request")
			return
		}
		if r.Header.Get("X-Essentials-Device") != identity.Device {
			writeError(w, http.StatusForbidden, "Device identity does not match credential")
			return
		}
		event := newInvalidation(parts[3], identity.Device)
		go s.push.publish(event)
		writeJSON(w, http.StatusAccepted, map[string]string{"eventId": event.EventID})
		return
	}
	writeError(w, http.StatusNotFound, "Unknown endpoint")
}

func (s *server) authenticate(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		value := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
		if value == "" || value == r.Header.Get("Authorization") {
			writeError(w, http.StatusUnauthorized, "Bearer authentication is required")
			return
		}
		identity, err := s.authenticateToken(value)
		if err != nil {
			writeError(w, http.StatusUnauthorized, "Invalid device credential")
			return
		}
		next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), identityKey{}, identity)))
	})
}

type identityKey struct{}

func (s *server) authenticateToken(candidate string) (authenticatedIdentity, error) {
	file, err := os.Open(s.tokenFile)
	if err != nil {
		return authenticatedIdentity{}, err
	}
	defer file.Close()
	candidateHash := sha256.Sum256([]byte(candidate))
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		device, token, found := strings.Cut(line, ":")
		if !found || !identifierPattern.MatchString(device) || token == "" {
			continue
		}
		expectedHash := sha256.Sum256([]byte(token))
		if subtle.ConstantTimeCompare(candidateHash[:], expectedHash[:]) != 1 {
			continue
		}
		record, found := s.identities[device]
		if !found {
			return authenticatedIdentity{Device: device, User: device, Groups: map[string]struct{}{}}, nil
		}
		groups := make(map[string]struct{}, len(record.Groups))
		for _, group := range record.Groups {
			groups[group] = struct{}{}
		}
		return authenticatedIdentity{Device: device, User: record.User, Groups: groups}, nil
	}
	return authenticatedIdentity{}, errors.New("token not found")
}

func loadIdentityRegistry(path string) (map[string]identityRecord, error) {
	if path == "" {
		return map[string]identityRecord{}, nil
	}
	contents, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read identity registry: %w", err)
	}
	var registry identityRegistry
	decoder := json.NewDecoder(strings.NewReader(string(contents)))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&registry); err != nil {
		return nil, fmt.Errorf("decode identity registry: %w", err)
	}
	if decoder.Decode(&struct{}{}) != io.EOF {
		return nil, errors.New("decode identity registry: trailing data")
	}
	if registry.Devices == nil {
		registry.Devices = map[string]identityRecord{}
	}
	for device, identity := range registry.Devices {
		if !validIdentifiers(device, identity.User) {
			return nil, fmt.Errorf("invalid identity for device %q", device)
		}
		seenGroups := map[string]struct{}{}
		for _, group := range identity.Groups {
			if !identifierPattern.MatchString(group) {
				return nil, fmt.Errorf("invalid group for device %q", device)
			}
			if _, exists := seenGroups[group]; exists {
				return nil, fmt.Errorf("duplicate group for device %q", device)
			}
			seenGroups[group] = struct{}{}
		}
	}
	return registry.Devices, nil
}

func validIdentifiers(values ...string) bool {
	for _, value := range values {
		if !identifierPattern.MatchString(value) {
			return false
		}
	}
	return true
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}

func writeError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, map[string]string{"error": message})
}

func writeFileAtomically(path string, contents []byte, mode os.FileMode) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	temporary, err := os.CreateTemp(filepath.Dir(path), ".tmp-")
	if err != nil {
		return err
	}
	temporaryName := temporary.Name()
	defer os.Remove(temporaryName)
	if err := temporary.Chmod(mode); err != nil {
		temporary.Close()
		return err
	}
	if _, err := temporary.Write(contents); err != nil {
		temporary.Close()
		return err
	}
	if err := temporary.Sync(); err != nil {
		temporary.Close()
		return err
	}
	if err := temporary.Close(); err != nil {
		return err
	}
	return os.Rename(temporaryName, path)
}
