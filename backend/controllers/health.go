package controllers

import (
	"encoding/json"
	"net/http"
)

// HealthCheck returns the health status of the backend
func HealthCheck(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}
