package controllers

import (
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"

	"github.com/DragonEmperor9480/AethrOps/db_service"
	"github.com/DragonEmperor9480/AethrOps/service"
)

// SaveEmailConfig saves email configuration to file
func SaveEmailConfig(w http.ResponseWriter, r *http.Request) {
	var config service.EmailConfig

	if err := json.NewDecoder(r.Body).Decode(&config); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	// Validate required fields
	if config.SMTPHost == "" || config.SMTPPort == 0 || config.SenderEmail == "" || config.SenderPass == "" {
		respondError(w, http.StatusBadRequest, "All email configuration fields are required")
		return
	}

	// Get config directory (works for both mobile and desktop)
	configDir, err := db_service.GetConfigDirectory()
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to get config directory")
		return
	}

	// Write email config to file
	emailConfigFile := filepath.Join(configDir, "email_config.json")
	configData, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to marshal email config")
		return
	}

	if err := os.WriteFile(emailConfigFile, configData, 0600); err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to write email config file")
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{
		"message": "Email configuration saved successfully",
	})
}

// GetEmailConfig retrieves email configuration from file
func GetEmailConfig(w http.ResponseWriter, r *http.Request) {
	config, err := service.LoadEmailConfig()
	if err != nil {
		respondJSON(w, http.StatusOK, map[string]interface{}{
			"configured": false,
			"message":    err.Error(),
		})
		return
	}

	// Send the password back to the client (safe for local desktop app hehehe)
	respondJSON(w, http.StatusOK, map[string]interface{}{
		"configured":   true,
		"smtp_host":    config.SMTPHost,
		"smtp_port":    config.SMTPPort,
		"sender_email": config.SenderEmail,
		"sender_pass":  config.SenderPass,
		"sender_name":  config.SenderName,
	})
}

// DeleteEmailConfig deletes the email configuration file
func DeleteEmailConfig(w http.ResponseWriter, r *http.Request) {
	// Get config directory (works for both mobile and desktop)
	configDir, err := db_service.GetConfigDirectory()
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to get config directory")
		return
	}

	emailConfigFile := filepath.Join(configDir, "email_config.json")

	// Check if file exists
	if _, err := os.Stat(emailConfigFile); os.IsNotExist(err) {
		respondJSON(w, http.StatusOK, map[string]string{
			"message": "Email configuration not found",
		})
		return
	}

	// Delete the file
	if err := os.Remove(emailConfigFile); err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to delete email config file")
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{
		"message": "Email configuration deleted successfully",
	})
}

// SendTestEmail attempts to send a test email with the provided configuration
func SendTestEmail(w http.ResponseWriter, r *http.Request) {
	var config service.EmailConfig

	if err := json.NewDecoder(r.Body).Decode(&config); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	// Validate required fields
	if config.SMTPHost == "" || config.SMTPPort == 0 || config.SenderEmail == "" || config.SenderPass == "" {
		respondError(w, http.StatusBadRequest, "All SMTP settings (Host, Port, Email, Password) are required")
		return
	}

	// Send Test Email via Service
	if err := service.SendTestEmail(&config, config.SenderEmail); err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to send test email: "+err.Error())
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{
		"message": "Test email sent successfully to " + config.SenderEmail,
	})
}
