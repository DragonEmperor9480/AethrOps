package controllers

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/DragonEmperor9480/AethrOps/service"
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

	// Validate that the file path is within the expected log directory
	logDir := service.GetLogDirectory()
	cleanPath := filepath.Clean(session.FilePath)
	cleanLogDir := filepath.Clean(logDir)

	// Check if cleanPath starts with cleanLogDir and has a path separator after it
	if !strings.HasPrefix(cleanPath, cleanLogDir) ||
		(len(cleanPath) > len(cleanLogDir) && cleanPath[len(cleanLogDir)] != filepath.Separator) {
		respondError(w, http.StatusForbidden, "Invalid file path")
		return
	}

	// Close the file for writing before reading
	session.Mutex.Lock()
	if session.File != nil {
		if err := session.File.Sync(); err != nil {
			session.Mutex.Unlock()
			respondError(w, http.StatusInternalServerError, "Failed to sync log file")
			return
		}
	}
	session.Mutex.Unlock()

	// Open file for reading
	file, err := os.Open(cleanPath)
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
