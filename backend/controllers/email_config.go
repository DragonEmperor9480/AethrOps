package controllers

import (
	"encoding/json"
	"net/http"

	"github.com/DragonEmperor9480/AethrOps/service"
)

// SaveEmailConfig saves email configuration to file. An empty sender_pass keeps
// the currently saved password.
func SaveEmailConfig(w http.ResponseWriter, r *http.Request) {
	var config service.EmailConfig

	if err := json.NewDecoder(r.Body).Decode(&config); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	// Validate required fields (password may be omitted to keep the saved one)
	if config.SMTPHost == "" || config.SMTPPort == 0 || config.SenderEmail == "" {
		respondError(w, http.StatusBadRequest, "All email configuration fields are required")
		return
	}

	if err := service.SaveEmailConfig(config); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{
		"message": "Email configuration saved successfully",
	})
}

// GetEmailConfig retrieves email configuration. The SMTP password is never
// returned; has_password tells the UI whether one is saved.
func GetEmailConfig(w http.ResponseWriter, r *http.Request) {
	config, err := service.LoadEmailConfig()
	if err != nil {
		respondJSON(w, http.StatusOK, map[string]interface{}{
			"configured": false,
			"message":    err.Error(),
		})
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"configured":   true,
		"smtp_host":    config.SMTPHost,
		"smtp_port":    config.SMTPPort,
		"sender_email": config.SenderEmail,
		"sender_name":  config.SenderName,
		"has_password": config.SenderPass != "",
	})
}

// DeleteEmailConfig deletes the email configuration file
func DeleteEmailConfig(w http.ResponseWriter, r *http.Request) {
	deleted, err := service.DeleteEmailConfig()
	if err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}

	if !deleted {
		respondJSON(w, http.StatusOK, map[string]string{
			"message": "Email configuration not found",
		})
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{
		"message": "Email configuration deleted successfully",
	})
}

// SendTestEmail attempts to send a test email with the provided configuration.
// An empty sender_pass uses the saved password, but only for the same SMTP host
// and sender, so the saved password is never sent to a different server.
func SendTestEmail(w http.ResponseWriter, r *http.Request) {
	var config service.EmailConfig

	if err := json.NewDecoder(r.Body).Decode(&config); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	// Validate required fields
	if config.SMTPHost == "" || config.SMTPPort == 0 || config.SenderEmail == "" {
		respondError(w, http.StatusBadRequest, "All SMTP settings (Host, Port, Email, Password) are required")
		return
	}

	if config.SenderPass == "" {
		saved, err := service.LoadEmailConfig()
		if err != nil || saved.SenderPass == "" ||
			saved.SMTPHost != config.SMTPHost || saved.SenderEmail != config.SenderEmail {
			respondError(w, http.StatusBadRequest, "Password is required when the SMTP host or sender email changes")
			return
		}
		config.SenderPass = saved.SenderPass
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
