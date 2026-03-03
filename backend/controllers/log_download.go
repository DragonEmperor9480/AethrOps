package controllers

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"

	"github.com/DragonEmperor9480/aws_cli_manager/service"
	"github.com/gorilla/mux"
)

// DownloadLogs serves the captured logs for a session
func DownloadLogs(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	sessionID := vars["sessionId"]

	session, exists := service.GetLogSession(sessionID)
	if !exists {
		respondError(w, http.StatusNotFound, "Log session not found")
		return
	}

	// Close the file for writing before reading
	session.Mutex.Lock()
	if session.File != nil {
		session.File.Sync() // Ensure all data is written
	}
	session.Mutex.Unlock()

	// Open file for reading
	file, err := os.Open(session.FilePath)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to open log file")
		return
	}
	defer file.Close()

	// Get file info for size
	fileInfo, err := file.Stat()
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to get file info")
		return
	}

	// Set headers for download
	filename := filepath.Base(session.FilePath)
	w.Header().Set("Content-Type", "text/plain")
	w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=\"%s\"", filename))
	w.Header().Set("Content-Length", fmt.Sprintf("%d", fileInfo.Size()))
	w.Header().Set("Access-Control-Allow-Origin", "*")

	// Stream file to client
	if _, err := io.Copy(w, file); err != nil {
		// Can't send error response after starting to write body
		return
	}
}
