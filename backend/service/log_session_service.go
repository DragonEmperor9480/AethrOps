package service

import (
	"context"
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

// InitLogDirectory initializes the log directory (call after setting AETHROPS_DATA_DIR)
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
	if dataDir := os.Getenv("AETHROPS_DATA_DIR"); dataDir != "" {
		return filepath.Join(dataDir, "logs")
	}

	// Fallback to /tmp for desktop platforms
	return "/tmp/aethrops_logs"
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

	ctx, cancel := context.WithCancel(context.Background())

	session := &cloudwatch_model.LogSession{
		SessionID:    sessionID,
		FunctionName: functionName,
		FilePath:     filePath,
		File:         file,
		CreatedAt:    time.Now(),
		LastAccess:   time.Now(),
		LogCount:     0,
		LogChan:      make(chan cloudwatch_model.LogEntry, 5000),
		CancelFunc:   cancel,
	}

	startBackgroundWriter(session, ctx)

	logSessionsMutex.Lock()
	logSessions[sessionID] = session
	logSessionsMutex.Unlock()

	return session, nil
}

// startBackgroundWriter launches a single dedicated background worker for the session log file
func startBackgroundWriter(session *cloudwatch_model.LogSession, ctx context.Context) {
	session.WG.Add(1)
	go func() {
		defer session.WG.Done()
		for {
			select {
			case <-ctx.Done():
				// Context cancelled - drain remaining items in channel
				for {
					select {
					case entry, ok := <-session.LogChan:
						if !ok {
							return
						}
						writeLogToDisk(session, entry)
					default:
						return
					}
				}
			case entry, ok := <-session.LogChan:
				if !ok {
					return
				}
				writeLogToDisk(session, entry)
			}
		}
	}()
}

// writeLogToDisk performs the actual synchronized write to the file
func writeLogToDisk(session *cloudwatch_model.LogSession, entry cloudwatch_model.LogEntry) {
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

// WriteLogToFile non-blockingly queues a log entry to be written asynchronously by the background writer
func WriteLogToFile(session *cloudwatch_model.LogSession, entry cloudwatch_model.LogEntry) {
	if session.LogChan == nil {
		return
	}
	select {
	case session.LogChan <- entry:
	default:
		// Queue full - drop log to prevent blocking main SSE stream
	}
}

// CloseLogSession closes a log session, flushes background logs, deletes the log file, and removes the session.
func CloseLogSession(sessionID string) {
	logSessionsMutex.Lock()
	session, exists := logSessions[sessionID]
	if !exists {
		logSessionsMutex.Unlock()
		return
	}
	delete(logSessions, sessionID)
	logSessionsMutex.Unlock()

	// Stop background writer and close channel
	if session.CancelFunc != nil {
		session.CancelFunc()
	}
	if session.LogChan != nil {
		close(session.LogChan)
	}

	// Wait for background worker to completely drain and exit
	session.WG.Wait()

	session.Mutex.Lock()
	defer session.Mutex.Unlock()

	if session.File != nil {
		_ = session.File.Close()
		session.File = nil
	}

	// Delete the log file from disk
	if session.FilePath != "" {
		_ = os.Remove(session.FilePath)
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

// DeleteLogSession removes a session, flushes background logs, and deletes its file
func DeleteLogSession(sessionID string) error {
	logSessionsMutex.Lock()
	session, exists := logSessions[sessionID]
	if !exists {
		logSessionsMutex.Unlock()
		return fmt.Errorf("session not found")
	}
	delete(logSessions, sessionID)
	logSessionsMutex.Unlock()

	// Stop background writer and close channel
	if session.CancelFunc != nil {
		session.CancelFunc()
	}
	if session.LogChan != nil {
		close(session.LogChan)
	}

	// Wait for background worker to completely drain and exit
	session.WG.Wait()

	session.Mutex.Lock()
	defer session.Mutex.Unlock()

	if session.File != nil {
		_ = session.File.Close()
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
			_ = DeleteLogSession(sessionID)
		}
	}
}
