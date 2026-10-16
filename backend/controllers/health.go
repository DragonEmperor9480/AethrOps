package controllers

import (
	"net/http"

	"github.com/DragonEmperor9480/AethrOps/models"
	"github.com/DragonEmperor9480/AethrOps/utils"
)

// HealthCheck returns the health status of the backend
func HealthCheck(w http.ResponseWriter, r *http.Request) {
	utils.JSON(w, http.StatusOK, models.Response{
		Status: true,
	})
}
