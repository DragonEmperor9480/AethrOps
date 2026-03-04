package controllers

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	cloudwatch_model "github.com/DragonEmperor9480/AethrOps/models/cloudwatch"
	"github.com/DragonEmperor9480/AethrOps/service"
	"github.com/gorilla/mux"
)

// ListLambdaFunctions lists all Lambda functions
func ListLambdaFunctions(w http.ResponseWriter, r *http.Request) {
	output, err := service.FetchLambdaFunctions()
	if err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}

	// Parse function names
	functions := []string{}
	lines := string(output)
	for _, line := range splitLines(lines) {
		if line != "" {
			functions = append(functions, line)
		}
	}

	respondJSON(w, http.StatusOK, map[string]any{
		"functions": functions,
	})
}

// StreamLambdaLogs streams Lambda logs using Server-Sent Events (SSE)
// and simultaneously writes them to a temporary file for download
func StreamLambdaLogs(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	functionName := vars["function"]
	logGroupName := "/aws/lambda/" + functionName

	// Set headers for SSE
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("X-Accel-Buffering", "no") // Disable proxy buffering (nginx)

	// Create log session for this stream
	session, err := service.CreateLogSession(functionName)
	if err != nil {
		// Log the actual error for debugging
		fmt.Printf("ERROR: Failed to create log session: %v\n", err)
		respondError(w, http.StatusInternalServerError, "Failed to create log session: "+err.Error())
		return
	}
	defer service.CloseLogSession(session.SessionID)

	// Create channels for log streaming
	logChan := make(chan cloudwatch_model.LogEntry, 200)
	errChan := make(chan error, 1)
	ctx, cancel := context.WithCancel(r.Context())
	defer cancel()

	// Start streaming logs
	go service.StreamLambdaLogs(ctx, logGroupName, logChan, errChan)

	// Create a flusher for SSE
	flusher, ok := w.(http.Flusher)
	if !ok {
		respondError(w, http.StatusInternalServerError, "Streaming not supported")
		return
	}

	// Check for SSE reconnection via Last-Event-ID header
	lastEventID := r.Header.Get("Last-Event-ID")

	// Monotonic SSE event ID counter
	var eventID uint64
	if lastEventID != "" {
		// Parse the last event ID client sent — resume numbering from there
		fmt.Sscanf(lastEventID, "%d", &eventID)
	}

	// Send initial connection message with session ID
	eventID++
	if _, err := fmt.Fprintf(w, "id: %d\ndata: {\"type\":\"connected\",\"function\":\"%s\",\"sessionId\":\"%s\"}\n\n",
		eventID, functionName, session.SessionID); err != nil {
		return // Client already disconnected
	}
	flusher.Flush()

	// Stream logs to client with adaptive batching
	keepaliveTicker := time.NewTicker(30 * time.Second)
	defer keepaliveTicker.Stop()

	// Adaptive batch drain timer — shorter for low volume, longer for bursts
	const minBatchDuration = 10 * time.Millisecond // Faster for low volume
	const maxBatchDuration = 50 * time.Millisecond // Cap for high volume

	batchDrainDuration := minBatchDuration

	for {
		select {
		case <-ctx.Done():
			return

		case <-keepaliveTicker.C:
			// Send keepalive comment (not a data event, no id needed)
			if _, err := fmt.Fprintf(w, ": keepalive\n\n"); err != nil {
				return // Client disconnected
			}
			flusher.Flush()

		case logEntry := <-logChan:
			// Write to file asynchronously (non-blocking)
			go service.WriteLogToFile(session, logEntry)

			// First event received — start batching
			if err := writeLogSSE(w, &eventID, logEntry); err != nil {
				return // Client disconnected
			}

			// Check if more logs are immediately available
			batchCount := 1
			drainTimer := time.NewTimer(batchDrainDuration)
		drainLoop:
			for {
				select {
				case <-ctx.Done():
					drainTimer.Stop()
					return
				case entry := <-logChan:
					// Write to file asynchronously
					go service.WriteLogToFile(session, entry)

					if err := writeLogSSE(w, &eventID, entry); err != nil {
						drainTimer.Stop()
						return
					}
					batchCount++
					// Adjust batch duration based on volume
					if batchCount > 10 {
						batchDrainDuration = maxBatchDuration
					} else {
						batchDrainDuration = minBatchDuration
					}
				case <-drainTimer.C:
					break drainLoop
				}
			}

			// Flush the entire batch at once
			flusher.Flush()

		case err := <-errChan:
			if err != nil {
				eventID++
				data, _ := json.Marshal(map[string]any{
					"type":  "error",
					"error": err.Error(),
				})
				fmt.Fprintf(w, "id: %d\ndata: %s\n\n", eventID, data)
				flusher.Flush()
				return
			}
		}
	}
}

// writeLogSSE writes a single log entry as an SSE event with an incrementing ID.
// Returns an error if the write fails (client disconnected).
func writeLogSSE(w http.ResponseWriter, eventID *uint64, entry cloudwatch_model.LogEntry) error {
	*eventID++
	data, err := json.Marshal(map[string]any{
		"type":      "log",
		"message":   entry.Message,
		"timestamp": entry.Timestamp,
		"eventId":   entry.EventID,
	})
	if err != nil {
		return nil // Skip malformed entries, not a connection error
	}
	_, writeErr := fmt.Fprintf(w, "id: %d\ndata: %s\n\n", *eventID, data)
	return writeErr
}

func splitLines(s string) []string {
	if s == "" {
		return []string{}
	}
	lines := []string{}
	for _, line := range strings.Split(strings.TrimSpace(s), "\n") {
		if line != "" {
			lines = append(lines, line)
		}
	}
	return lines
}
