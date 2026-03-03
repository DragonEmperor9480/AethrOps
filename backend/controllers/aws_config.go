package controllers

import (
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/DragonEmperor9480/AethrOps/db_service"
	"github.com/DragonEmperor9480/AethrOps/utils"
)

// ConfigureAWS configures AWS credentials
func ConfigureAWS(w http.ResponseWriter, r *http.Request) {
	var req struct {
		AccessKeyID     string `json:"access_key_id"`
		SecretAccessKey string `json:"secret_access_key"`
		Region          string `json:"region"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	if req.AccessKeyID == "" || req.SecretAccessKey == "" || req.Region == "" {
		respondError(w, http.StatusBadRequest, "All fields are required")
		return
	}

	// Get config directory (works for both mobile and desktop)
	configDir, err := db_service.GetConfigDirectory()
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to get config directory")
		return
	}

	// Write credentials file
	credentialsFile := filepath.Join(configDir, "credentials")
	credentialsContent := `[default]
aws_access_key_id = ` + req.AccessKeyID + `
aws_secret_access_key = ` + req.SecretAccessKey + `
`

	if err := os.WriteFile(credentialsFile, []byte(credentialsContent), 0600); err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to write credentials file")
		return
	}

	// Write config file
	configFile := filepath.Join(configDir, "config")
	configContent := `[default]
region = ` + req.Region + `
output = json
`

	if err := os.WriteFile(configFile, []byte(configContent), 0600); err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to write config file")
		return
	}

	// IMPORTANT: Reload AWS clients with new credentials
	if err := utils.InitAWSClients(); err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to initialize AWS clients: "+err.Error())
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{"message": "AWS credentials configured successfully"})
}

// DeleteAWSConfig deletes AWS credentials and config files
func DeleteAWSConfig(w http.ResponseWriter, r *http.Request) {
	// Get config directory
	configDir, err := db_service.GetConfigDirectory()
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to get config directory")
		return
	}

	credentialsFile := filepath.Join(configDir, "credentials")
	configFile := filepath.Join(configDir, "config")

	// Delete credentials file (ignore error if not exists)
	os.Remove(credentialsFile)

	// Delete config file (ignore error if not exists)
	os.Remove(configFile)

	respondJSON(w, http.StatusOK, map[string]string{"message": "AWS credentials deleted successfully"})
}

// GetAWSConfig gets current AWS configuration
func GetAWSConfig(w http.ResponseWriter, r *http.Request) {
	// Get config directory (works for both mobile and desktop)
	configDir, err := db_service.GetConfigDirectory()
	if err != nil {
		respondJSON(w, http.StatusOK, map[string]interface{}{
			"configured": false,
			"message":    "Failed to get config directory",
		})
		return
	}

	credentialsFile := filepath.Join(configDir, "credentials")
	configFile := filepath.Join(configDir, "config")

	// Check if credentials file exists and is not empty
	credInfo, err := os.Stat(credentialsFile)
	if err != nil || credInfo.Size() == 0 {
		respondJSON(w, http.StatusOK, map[string]interface{}{
			"configured": false,
			"message":    "AWS credentials file not found",
		})
		return
	}

	// Check if config file exists
	_, err = os.Stat(configFile)
	if err != nil {
		respondJSON(w, http.StatusOK, map[string]interface{}{
			"configured": false,
			"message":    "AWS config file not found",
		})
		return
	}

	// Try to read credentials to verify they're valid format
	credContent, err := os.ReadFile(credentialsFile)
	if err != nil {
		respondJSON(w, http.StatusOK, map[string]interface{}{
			"configured": false,
			"message":    "Failed to read credentials file",
		})
		return
	}

	credStr := string(credContent)
	if !strings.Contains(credStr, "aws_access_key_id") || !strings.Contains(credStr, "aws_secret_access_key") {
		respondJSON(w, http.StatusOK, map[string]interface{}{
			"configured": false,
			"message":    "Credentials file is invalid",
		})
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"configured": true,
		"message":    "AWS credentials configured",
	})
}
