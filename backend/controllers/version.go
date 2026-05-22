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
