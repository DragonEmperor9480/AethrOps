package service

import (
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/DragonEmperor9480/AethrOps/db_service"
)

// configFilePath returns the path of a settings file (email, MFA) in the app's
// config directory: ~/.aethrops on desktop, <data dir>/config on mobile.
func configFilePath(name string) (string, error) {
	configDir, err := db_service.GetConfigDirectory()
	if err != nil {
		return "", fmt.Errorf("failed to get config directory: %v", err)
	}

	path := filepath.Join(configDir, name)
	migrateLegacyConfigFile(path, name)
	return path, nil
}

// Older desktop builds kept these files in ~/.aws (the AWS CLI's directory).
// Move a file over once so existing settings are not lost.
func migrateLegacyConfigFile(path, name string) {
	if os.Getenv("AETHROPS_DATA_DIR") != "" {
		return // mobile never used ~/.aws
	}
	if _, err := os.Stat(path); err == nil {
		return // already present in the new location
	}

	homeDir, err := os.UserHomeDir()
	if err != nil {
		return
	}
	legacyPath := filepath.Join(homeDir, ".aws", name)
	if _, err := os.Stat(legacyPath); err != nil {
		return
	}

	if err := os.Rename(legacyPath, path); err != nil {
		log.Printf("Warning: failed to move %s to %s: %v", legacyPath, path, err)
		return
	}
	_ = os.Chmod(path, 0600)
	log.Printf("Moved legacy config file %s to %s", legacyPath, path)
}
