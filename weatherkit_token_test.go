package skua

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"errors"
	"math/big"
	"strings"
	"testing"
	"time"
)

// testKeyPEM generates a P-256 private key encoded as PKCS8 PEM for tests.
func testKeyPEM(t *testing.T) ([]byte, *ecdsa.PublicKey) {
	t.Helper()
	priv, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatalf("generate key: %v", err)
	}
	der, err := x509.MarshalPKCS8PrivateKey(priv)
	if err != nil {
		t.Fatalf("marshal key: %v", err)
	}
	pemBytes := pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der})
	return pemBytes, &priv.PublicKey
}

// decodeSeg base64url-decodes a JWT segment into v.
func decodeSeg(t *testing.T, seg string, v any) {
	t.Helper()
	raw, err := base64.RawURLEncoding.DecodeString(seg)
	if err != nil {
		t.Fatalf("decode segment: %v", err)
	}
	if err := json.Unmarshal(raw, v); err != nil {
		t.Fatalf("unmarshal segment: %v", err)
	}
}

// TestAppleKeyToken mints a token and verifies its claims and signature.
func TestAppleKeyToken(t *testing.T) {
	t.Parallel()
	pemBytes, pub := testKeyPEM(t)
	key, err := parseAppleKey("TEAM123456", "com.skua.weather", "KEY7890", pemBytes)
	if err != nil {
		t.Fatalf("parseAppleKey: %v", err)
	}
	now := time.Unix(1000000000, 0)
	tok, err := key.token(now, time.Hour)
	if err != nil {
		t.Fatalf("token: %v", err)
	}
	parts := strings.Split(tok, ".")
	if len(parts) != 3 {
		t.Fatalf("token parts = %d, want 3", len(parts))
	}

	var header map[string]string
	decodeSeg(t, parts[0], &header)
	if header["alg"] != "ES256" {
		t.Errorf("alg = %q, want ES256", header["alg"])
	}
	if header["kid"] != "KEY7890" {
		t.Errorf("kid = %q, want KEY7890", header["kid"])
	}
	if header["id"] != "TEAM123456.com.skua.weather" {
		t.Errorf("id = %q, want TEAM123456.com.skua.weather", header["id"])
	}

	var claims map[string]any
	decodeSeg(t, parts[1], &claims)
	if claims["iss"] != "TEAM123456" {
		t.Errorf("iss = %v, want TEAM123456", claims["iss"])
	}
	if claims["sub"] != "com.skua.weather" {
		t.Errorf("sub = %v, want com.skua.weather", claims["sub"])
	}

	signingInput := parts[0] + "." + parts[1]
	digest := sha256.Sum256([]byte(signingInput))
	sig, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil || len(sig) != 64 {
		t.Fatalf("bad signature segment: err=%v len=%d", err, len(sig))
	}
	r := new(big.Int).SetBytes(sig[:32])
	s := new(big.Int).SetBytes(sig[32:])
	if !ecdsa.Verify(pub, digest[:], r, s) {
		t.Error("signature did not verify")
	}
}

// TestParseAppleKeyBad rejects input that is not a PEM key.
func TestParseAppleKeyBad(t *testing.T) {
	t.Parallel()
	if _, err := parseAppleKey("t", "s", "k", []byte("not a pem")); !errors.Is(err, ErrConfig) {
		t.Errorf("want ErrConfig, got %v", err)
	}
}
