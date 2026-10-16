package db_service

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"sync"
)

const keyFileName = "secret.key"

var (
	encryptionKey   []byte
	encryptionKeyMu sync.Mutex
)

// getEncryptionKey returns the per-install AES-256 key, creating it on first use.
// It lives in the config directory with owner-only permissions.
func getEncryptionKey() ([]byte, error) {
	encryptionKeyMu.Lock()
	defer encryptionKeyMu.Unlock()

	if encryptionKey != nil {
		return encryptionKey, nil
	}

	configDir, err := GetConfigDirectory()
	if err != nil {
		return nil, fmt.Errorf("failed to get config directory: %w", err)
	}
	keyPath := filepath.Join(configDir, keyFileName)

	key, err := os.ReadFile(keyPath)
	if err == nil {
		if len(key) != 32 {
			return nil, fmt.Errorf("encryption key %s is corrupt (expected 32 bytes, got %d)", keyPath, len(key))
		}
		encryptionKey = key
		return encryptionKey, nil
	}
	if !errors.Is(err, os.ErrNotExist) {
		return nil, fmt.Errorf("failed to read encryption key: %w", err)
	}

	key = make([]byte, 32)
	if _, err := io.ReadFull(rand.Reader, key); err != nil {
		return nil, fmt.Errorf("failed to generate encryption key: %w", err)
	}
	// O_EXCL: never overwrite a key another process just created
	f, err := os.OpenFile(keyPath, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	if err != nil {
		return nil, fmt.Errorf("failed to create encryption key: %w", err)
	}
	if _, err := f.Write(key); err != nil {
		f.Close()
		return nil, fmt.Errorf("failed to write encryption key: %w", err)
	}
	if err := f.Close(); err != nil {
		return nil, fmt.Errorf("failed to write encryption key: %w", err)
	}

	log.Printf("Created new encryption key at %s", keyPath)
	encryptionKey = key
	return encryptionKey, nil
}

// Encrypt encrypts a string using AES-256-GCM with the per-install key
func Encrypt(plaintext string) (string, error) {
	key, err := getEncryptionKey()
	if err != nil {
		return "", err
	}
	return encryptWithKey(key, plaintext)
}

// Decrypt decrypts a string produced by Encrypt
func Decrypt(ciphertext string) (string, error) {
	key, err := getEncryptionKey()
	if err != nil {
		return "", err
	}
	return decryptWithKey(key, ciphertext)
}

func encryptWithKey(key []byte, plaintext string) (string, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}

	nonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return "", err
	}

	ciphertext := gcm.Seal(nonce, nonce, []byte(plaintext), nil)
	return base64.StdEncoding.EncodeToString(ciphertext), nil
}

func decryptWithKey(key []byte, ciphertext string) (string, error) {
	data, err := base64.StdEncoding.DecodeString(ciphertext)
	if err != nil {
		return "", err
	}

	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}

	nonceSize := gcm.NonceSize()
	if len(data) < nonceSize {
		return "", fmt.Errorf("ciphertext too short")
	}

	nonce, ciphertextBytes := data[:nonceSize], data[nonceSize:]
	plaintext, err := gcm.Open(nil, nonce, ciphertextBytes, nil)
	if err != nil {
		return "", err
	}

	return string(plaintext), nil
}
