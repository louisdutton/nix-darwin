package main

import (
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"time"

	webpush "github.com/SherClockHolmes/webpush-go"
)

const invalidationProtocolVersion = 1

type pushPublisher struct {
	root         string
	endpointBase *url.URL
	vapidPublic  string
	vapidPrivate string
	vapidSubject string
	httpClient   *http.Client
}

type pushSubscription struct {
	ProtocolVersion int    `json:"protocolVersion"`
	Principal       string `json:"principal"`
	DeviceID        string `json:"deviceId"`
	Endpoint        string `json:"endpoint"`
	P256DH          string `json:"p256dh"`
	Auth            string `json:"auth"`
	Temporary       bool   `json:"temporary"`
	Updated         string `json:"updated"`
}

type invalidation struct {
	ProtocolVersion int    `json:"protocolVersion"`
	Namespace       string `json:"namespace"`
	EventID         string `json:"eventId"`
	OriginDeviceID  string `json:"originDeviceId,omitempty"`
}

type invalidationRequest struct {
	ProtocolVersion int    `json:"protocolVersion"`
	Namespace       string `json:"namespace"`
	OriginDeviceID  string `json:"originDeviceId,omitempty"`
}

func newPushPublisher(root, endpointBase, publicFile, privateFile, subject string) (*pushPublisher, error) {
	values := []string{endpointBase, publicFile, privateFile, subject}
	configured := 0
	for _, value := range values {
		if value != "" {
			configured++
		}
	}
	if configured == 0 {
		return nil, nil
	}
	if configured != len(values) {
		return nil, errors.New("push endpoint, both VAPID key files, and VAPID subject must be configured together")
	}
	base, err := url.Parse(endpointBase)
	if err != nil || base.Scheme == "" || base.Host == "" || base.User != nil || base.RawQuery != "" || base.Fragment != "" {
		return nil, errors.New("invalid push endpoint base URL")
	}
	publicKey, err := readSecret(publicFile)
	if err != nil {
		return nil, fmt.Errorf("read VAPID public key: %w", err)
	}
	privateKey, err := readSecret(privateFile)
	if err != nil {
		return nil, fmt.Errorf("read VAPID private key: %w", err)
	}
	return &pushPublisher{
		root: root, endpointBase: base,
		vapidPublic: publicKey, vapidPrivate: privateKey, vapidSubject: subject,
		httpClient: &http.Client{Timeout: 15 * time.Second},
	}, nil
}

func readSecret(path string) (string, error) {
	contents, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	value := strings.TrimSpace(string(contents))
	if value == "" {
		return "", errors.New("secret is empty")
	}
	return value, nil
}

func (s *server) handleVAPID(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		w.Header().Set("Allow", "GET")
		writeError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"protocolVersion": invalidationProtocolVersion,
		"publicKey":       s.push.vapidPublic,
	})
}

func (s *server) handlePushSubscription(
	w http.ResponseWriter,
	r *http.Request,
	identity authenticatedIdentity,
	deviceID string,
) {
	requestDevice := r.Header.Get("X-Essentials-Device")
	if requestDevice != deviceID || identity.Device != deviceID {
		writeError(w, http.StatusForbidden, "Device identity does not match credential")
		return
	}
	principal := identity.User
	path := s.push.subscriptionPath(principal, deviceID)
	switch r.Method {
	case http.MethodPut:
		var subscription pushSubscription
		decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 8*1024))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&subscription); err != nil || decoder.Decode(&struct{}{}) != io.EOF {
			writeError(w, http.StatusBadRequest, "Invalid push subscription")
			return
		}
		if subscription.ProtocolVersion != invalidationProtocolVersion ||
			subscription.P256DH == "" || subscription.Auth == "" ||
			!s.push.validEndpoint(subscription.Endpoint) {
			writeError(w, http.StatusBadRequest, "Invalid push subscription")
			return
		}
		subscription.Principal = principal
		subscription.DeviceID = deviceID
		subscription.Updated = time.Now().UTC().Format(time.RFC3339Nano)
		encoded, err := json.Marshal(subscription)
		if err != nil || writeFileAtomically(path, append(encoded, '\n'), 0o600) != nil {
			writeError(w, http.StatusInternalServerError, "Unable to store push subscription")
			return
		}
		w.WriteHeader(http.StatusNoContent)
	case http.MethodDelete:
		if err := os.Remove(path); err != nil && !errors.Is(err, os.ErrNotExist) {
			writeError(w, http.StatusInternalServerError, "Unable to remove push subscription")
			return
		}
		w.WriteHeader(http.StatusNoContent)
	default:
		w.Header().Set("Allow", "PUT, DELETE")
		writeError(w, http.StatusMethodNotAllowed, "Method not allowed")
	}
}

func (p *pushPublisher) validEndpoint(value string) bool {
	endpoint, err := url.Parse(value)
	return err == nil && endpoint.Scheme == p.endpointBase.Scheme &&
		endpoint.Host == p.endpointBase.Host && endpoint.User == nil && endpoint.Fragment == "" &&
		strings.HasPrefix(endpoint.EscapedPath(), "/up")
}

func (p *pushPublisher) subscriptionPath(principal, deviceID string) string {
	return filepath.Join(p.root, "subscriptions", principal, deviceID+".json")
}

func (s *server) authenticateInternal(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		expected, err := readSecret(s.internalToken)
		candidate := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
		if err != nil || candidate == "" || candidate == r.Header.Get("Authorization") ||
			!constantTimeEqual(candidate, expected) {
			writeError(w, http.StatusUnauthorized, "Invalid internal credential")
			return
		}
		next.ServeHTTP(w, r)
	})
}

func constantTimeEqual(left, right string) bool {
	leftHash := sha256.Sum256([]byte(left))
	rightHash := sha256.Sum256([]byte(right))
	return subtle.ConstantTimeCompare(leftHash[:], rightHash[:]) == 1
}

func (s *server) handleInvalidation(w http.ResponseWriter, r *http.Request) {
	var request invalidationRequest
	decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4*1024))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&request); err != nil || decoder.Decode(&struct{}{}) != io.EOF ||
		request.ProtocolVersion != invalidationProtocolVersion ||
		!identifierPattern.MatchString(request.Namespace) ||
		(request.OriginDeviceID != "" && !identifierPattern.MatchString(request.OriginDeviceID)) {
		writeError(w, http.StatusBadRequest, "Invalid invalidation request")
		return
	}
	event := newInvalidation(request.Namespace, request.OriginDeviceID)
	go s.push.publish(event)
	writeJSON(w, http.StatusAccepted, map[string]string{"eventId": event.EventID})
}

func newInvalidation(namespace, originDeviceID string) invalidation {
	random := make([]byte, 16)
	if _, err := rand.Read(random); err != nil {
		panic(err)
	}
	return invalidation{
		ProtocolVersion: invalidationProtocolVersion,
		Namespace:       namespace,
		EventID:         hex.EncodeToString(random),
		OriginDeviceID:  originDeviceID,
	}
}

func (p *pushPublisher) publish(event invalidation) {
	payload, err := json.Marshal(event)
	if err != nil {
		log.Printf("push invalidation encoding failed: %v", err)
		return
	}
	root := filepath.Join(p.root, "subscriptions")
	_ = filepath.WalkDir(root, func(path string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil || entry.IsDir() || filepath.Ext(path) != ".json" {
			return nil
		}
		contents, err := os.ReadFile(path)
		if err != nil {
			return nil
		}
		var subscription pushSubscription
		if json.Unmarshal(contents, &subscription) != nil ||
			subscription.ProtocolVersion != invalidationProtocolVersion ||
			subscription.DeviceID == event.OriginDeviceID || !p.validEndpoint(subscription.Endpoint) {
			return nil
		}
		response, err := webpush.SendNotification(payload, &webpush.Subscription{
			Endpoint: subscription.Endpoint,
			Keys:     webpush.Keys{P256dh: subscription.P256DH, Auth: subscription.Auth},
		}, &webpush.Options{
			HTTPClient: p.httpClient, Subscriber: p.vapidSubject,
			VAPIDPublicKey: p.vapidPublic, VAPIDPrivateKey: p.vapidPrivate,
			TTL: 300, Urgency: webpush.UrgencyHigh,
		})
		if err != nil {
			log.Printf("push invalidation failed for device %s: %v", subscription.DeviceID, err)
			return nil
		}
		response.Body.Close()
		if response.StatusCode == http.StatusNotFound || response.StatusCode == http.StatusGone {
			_ = os.Remove(path)
		} else if response.StatusCode < 200 || response.StatusCode >= 300 {
			log.Printf("push invalidation returned %d for device %s", response.StatusCode, subscription.DeviceID)
		}
		return nil
	})
}
