package controllers

import (
	"net/http"

	"github.com/DragonEmperor9480/AethrOps/utils"
)

// ReloadAWSCredentials reloads AWS credentials from the config files
// Useful when credentials are updated externally or need to be refreshed
func ReloadAWSCredentials(w http.ResponseWriter, r *http.Request) {
	if err := utils.InitAWSClients(); err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to reload AWS credentials: "+err.Error())
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{
		"message": "AWS credentials reloaded successfully",
	})
}
