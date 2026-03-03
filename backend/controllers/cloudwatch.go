package controllers

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	cloudwatch_model "github.com/DragonEmperor9480/aws_cli_manager/models/cloudwatch"
	"github.com/DragonEmperor9480/aws_cli_manager/service"
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

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"functions": functions,
	})
}

// StreamLambdaLogs streams Lambda logs using Server-Sent Events (SSE)
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

	// Send initial connection message
	eventID++
	if _, err := fmt.Fprintf(w, "id: %d\ndata: {\"type\":\"connected\",\"function\":\"%s\"}\n\n", eventID, functionName); err != nil {
		return // Client already disconnected
	}
	flusher.Flush()

	// Stream logs to client with batched flushing
	keepaliveTicker := time.NewTicker(30 * time.Second)
	defer keepaliveTicker.Stop()

	// Batch drain timer — collect burst events before flushing
	const batchDrainDuration = 50 * time.Millisecond

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
			// First event received — start batching
			if err := writeLogSSE(w, &eventID, logEntry); err != nil {
				return // Client disconnected
			}

			// Drain additional entries that arrived during the batch window
			drainTimer := time.NewTimer(batchDrainDuration)
		drainLoop:
			for {
				select {
				case <-ctx.Done():
					drainTimer.Stop()
					return
				case entry := <-logChan:
					if err := writeLogSSE(w, &eventID, entry); err != nil {
						drainTimer.Stop()
						return
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
				data, _ := json.Marshal(map[string]interface{}{
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
	data, err := json.Marshal(map[string]interface{}{
		"type":    "log",
		"message": entry.Message,
		"color":   entry.Color,
	})
	if err != nil {
		return nil // Skip malformed entries, not a connection error
	}
	_, writeErr := fmt.Fprintf(w, "id: %d\ndata: %s\n\n", *eventID, data)
	return writeErr
}

func splitLines(s string) []string {
	result := []string{}
	current := ""
	for _, ch := range s {
		if ch == '\n' {
			result = append(result, current)
			current = ""
		} else {
			current += string(ch)
		}
	}
	if current != "" {
		result = append(result, current)
	}
	return result
}
