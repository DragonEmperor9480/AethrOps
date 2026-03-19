package service

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"

	cloudwatch_model "github.com/DragonEmperor9480/AethrOps/models/cloudwatch"
)

var (
	logSessions      = make(map[string]*cloudwatch_model.LogSession)
	logSessionsMutex sync.RWMutex
	logDir           string
)

// Initialize cleanup goroutine and log directory
func init() {
	// Start cleanup goroutine
	go cleanupOldSessions()
}

// InitLogDirectory initializes the log directory (call after setting AWSMGR_DATA_DIR)
func InitLogDirectory() error {
	// Use platform-appropriate log directory
	logDir = getLogDirectory()

	// Create log directory if it doesn't exist
	if err := os.MkdirAll(logDir, 0750); err != nil {
		return fmt.Errorf("failed to create log directory: %w", err)
	}

	return nil
}

// getLogDirectory returns the appropriate log directory for the platform
func getLogDirectory() string {
	// Check if data directory is set (mobile platforms)
	if dataDir := os.Getenv("AWSMGR_DATA_DIR"); dataDir != "" {
		return filepath.Join(dataDir, "logs")
	}

	// Fallback to /tmp for desktop platforms
	return "/tmp/awsmgr_logs"
}

// GetLogDirectory returns the log directory (public accessor for validation)
func GetLogDirectory() string {
	return getLogDirectory()
}

// generateSessionID creates a unique session ID
func generateSessionID() string {
	bytes := make([]byte, 16)
	rand.Read(bytes)
	return hex.EncodeToString(bytes)
}

// CreateLogSession creates a new log session with a temporary file
func CreateLogSession(functionName string) (*cloudwatch_model.LogSession, error) {
	sessionID := generateSessionID()
	timestamp := time.Now().Format("20060102_150405")
	filename := fmt.Sprintf("%s_%s_%s.log", functionName, timestamp, sessionID[:8])
	filePath := filepath.Join(logDir, filename)

	file, err := os.Create(filePath)
	if err != nil {
		return nil, fmt.Errorf("failed to create log file: %w", err)
	}

	session := &cloudwatch_model.LogSession{
		SessionID:    sessionID,
		FunctionName: functionName,
		FilePath:     filePath,
		File:         file,
		CreatedAt:    time.Now(),
		LastAccess:   time.Now(),
		LogCount:     0,
	}

	logSessionsMutex.Lock()
	logSessions[sessionID] = session
	logSessionsMutex.Unlock()

	return session, nil
}

// WriteLogToFile writes a log entry to the session file (goroutine-safe)
func WriteLogToFile(session *cloudwatch_model.LogSession, entry cloudwatch_model.LogEntry) {
	session.Mutex.Lock()
	defer session.Mutex.Unlock()

	if session.File == nil {
		return
	}

	// Format: [timestamp] message
	timestamp := time.UnixMilli(entry.Timestamp).Format("2006-01-02 15:04:05.000")
	logLine := fmt.Sprintf("[%s] %s\n", timestamp, entry.Message)

	if _, err := session.File.WriteString(logLine); err != nil {
		return
	}

	session.LogCount++
	session.LastAccess = time.Now()
}

// CloseLogSession closes a log session, deletes the log file, and removes the session.
// Users can download logs via the download endpoint while the session is active,
// so the file is no longer needed once the stream ends.
func CloseLogSession(sessionID string) {
	logSessionsMutex.Lock()
	session, exists := logSessions[sessionID]
	if !exists {
		logSessionsMutex.Unlock()
		return
	}
	delete(logSessions, sessionID)
	logSessionsMutex.Unlock()

	session.Mutex.Lock()
	defer session.Mutex.Unlock()

	if session.File != nil {
		session.File.Close()
		session.File = nil
	}

	// Delete the log file from disk
	if session.FilePath != "" {
		if err := os.Remove(session.FilePath); err != nil {
			fmt.Printf("Warning: failed to delete log file %s: %v\n", session.FilePath, err)
		} else {
			fmt.Printf("Deleted log file: %s\n", session.FilePath)
		}
	}
}

// GetLogSession retrieves a log session by ID
func GetLogSession(sessionID string) (*cloudwatch_model.LogSession, bool) {
	logSessionsMutex.RLock()
	defer logSessionsMutex.RUnlock()

	session, exists := logSessions[sessionID]
	if exists {
		session.LastAccess = time.Now()
	}
	return session, exists
}

// DeleteLogSession removes a session and deletes its file
func DeleteLogSession(sessionID string) error {
	logSessionsMutex.Lock()
	session, exists := logSessions[sessionID]
	if !exists {
		logSessionsMutex.Unlock()
		return fmt.Errorf("session not found")
	}
	delete(logSessions, sessionID)
	logSessionsMutex.Unlock()

	session.Mutex.Lock()
	defer session.Mutex.Unlock()

	if session.File != nil {
		session.File.Close()
		session.File = nil
	}

	if err := os.Remove(session.FilePath); err != nil {
		return err
	}

	return nil
}

// cleanupOldSessions periodically removes old/inactive sessions
func cleanupOldSessions() {
	ticker := time.NewTicker(5 * time.Minute)
	defer ticker.Stop()

	for range ticker.C {
		now := time.Now()
		var toDelete []string

		logSessionsMutex.RLock()
		for sessionID, session := range logSessions {
			// Delete sessions older than 1 hour or inactive for 30 minutes
			if now.Sub(session.CreatedAt) > 1*time.Hour ||
				now.Sub(session.LastAccess) > 30*time.Minute {
				toDelete = append(toDelete, sessionID)
			}
		}
		logSessionsMutex.RUnlock()

		for _, sessionID := range toDelete {
			DeleteLogSession(sessionID)
		}
	}
}
