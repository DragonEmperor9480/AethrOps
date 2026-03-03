package service

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"sync"
	"time"

	cloudwatch_model "github.com/DragonEmperor9480/AethrOps/models/cloudwatch"
)

var (
	logSessions      = make(map[string]*cloudwatch_model.LogSession)
	logSessionsMutex sync.RWMutex
	logDir           = "/tmp/awsmgr_logs"
)

// Initialize cleanup goroutine and log directory
func init() {
	// Create log directory if it doesn't exist
	if err := os.MkdirAll(logDir, 0755); err != nil {
		log.Printf("Failed to create log directory: %v", err)
	}

	// Start cleanup goroutine
	go cleanupOldSessions()
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

	log.Printf("Created log session: %s for function: %s", sessionID, functionName)
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
		log.Printf("Failed to write log to file: %v", err)
		return
	}

	session.LogCount++
	session.LastAccess = time.Now()
}

// CloseLogSession closes a log session and its file
func CloseLogSession(sessionID string) {
	logSessionsMutex.Lock()
	defer logSessionsMutex.Unlock()

	session, exists := logSessions[sessionID]
	if !exists {
		return
	}

	session.Mutex.Lock()
	if session.File != nil {
		session.File.Close()
		session.File = nil
	}
	session.Mutex.Unlock()

	log.Printf("Closed log session: %s (%d logs captured)", sessionID, session.LogCount)
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
		log.Printf("Failed to delete log file: %v", err)
		return err
	}

	log.Printf("Deleted log session: %s", sessionID)
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

		if len(toDelete) > 0 {
			log.Printf("Cleaned up %d old log sessions", len(toDelete))
		}
	}
}
