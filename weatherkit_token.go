package skua

import (
	"crypto/ecdsa"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"time"
)

// appleKey holds a parsed WeatherKit signing key and its identifiers.
type appleKey struct {
	// teamID is the Apple Developer team identifier.
	teamID string
	// serviceID is the registered WeatherKit service identifier.
	serviceID string
	// keyID is the identifier of the signing key.
	keyID string
	// priv is the parsed ECDSA private key.
	priv *ecdsa.PrivateKey
}

// parseAppleKey parses a PEM-encoded PKCS8 EC private key with its identifiers.
func parseAppleKey(teamID, serviceID, keyID string, pemBytes []byte) (*appleKey, error) {
	block, _ := pem.Decode(pemBytes)
	if block == nil {
		return nil, fmt.Errorf("%w: no PEM block in key", ErrConfig)
	}
	parsed, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return nil, fmt.Errorf("%w: parse key: %w", ErrConfig, err)
	}
	priv, ok := parsed.(*ecdsa.PrivateKey)
	if !ok {
		return nil, fmt.Errorf("%w: key is not ECDSA", ErrConfig)
	}
	return &appleKey{teamID: teamID, serviceID: serviceID, keyID: keyID, priv: priv}, nil
}

// token mints a WeatherKit ES256 JWT valid for ttl starting at now.
func (k *appleKey) token(now time.Time, ttl time.Duration) (string, error) {
	header := map[string]string{
		"alg": "ES256",
		"kid": k.keyID,
		"id":  k.teamID + "." + k.serviceID,
		"typ": "JWT",
	}
	claims := map[string]any{
		"iss": k.teamID,
		"sub": k.serviceID,
		"iat": now.Unix(),
		"exp": now.Add(ttl).Unix(),
	}
	hb, err := json.Marshal(header)
	if err != nil {
		return "", err
	}
	cb, err := json.Marshal(claims)
	if err != nil {
		return "", err
	}
	signingInput := b64url(hb) + "." + b64url(cb)

	digest := sha256.Sum256([]byte(signingInput))
	r, s, err := ecdsa.Sign(rand.Reader, k.priv, digest[:])
	if err != nil {
		return "", err
	}
	sig := make([]byte, 64)
	r.FillBytes(sig[:32])
	s.FillBytes(sig[32:])
	return signingInput + "." + b64url(sig), nil
}

// b64url base64url-encodes b without padding, as JWT requires.
func b64url(b []byte) string {
	return base64.RawURLEncoding.EncodeToString(b)
}
