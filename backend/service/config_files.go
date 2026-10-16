package service

import (
	"fmt"
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

	return filepath.Join(configDir, name), nil
}
