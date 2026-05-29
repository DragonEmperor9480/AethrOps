package controllers

import (
	"net/http"

	"github.com/DragonEmperor9480/AethrOps/models"
)

// GetVersion returns version information
func GetVersion(w http.ResponseWriter, r *http.Request) {
	info := models.GetVersion()
	respondJSON(w, http.StatusOK, info)
}

// CheckVersionUpdate queries GitHub and returns update availability
func CheckVersionUpdate(w http.ResponseWriter, r *http.Request) {
	updateInfo, err := models.CheckForUpdates()
	if err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}
	respondJSON(w, http.StatusOK, updateInfo)
}
