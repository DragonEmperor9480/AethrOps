package controllers

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"
)

// Shutdown handles graceful shutdown of the backend
func Shutdown(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{"status": "shutting down"})
	log.Println("Shutdown requested, exiting gracefully...")

	// Close the server in a goroutine to allow response to be sent
	go func() {
		// Give time for response to be sent
		time.Sleep(100 * time.Millisecond)
		os.Exit(0)
	}()
}
