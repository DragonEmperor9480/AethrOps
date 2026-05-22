package service

import (
	"context"
	"log"
	"strings"
	"sync"
	"time"

	cloudwatch_model "github.com/DragonEmperor9480/AethrOps/models/cloudwatch"
	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/cloudwatchlogs"
	cwltypes "github.com/aws/aws-sdk-go-v2/service/cloudwatchlogs/types"
	"github.com/aws/aws-sdk-go-v2/service/lambda"
)

// Polling interval constants for adaptive polling
const (
	idlePollInterval   = 2 * time.Second        // Poll interval when no new logs are arriving
	activePollInterval = 200 * time.Millisecond // Poll interval when logs are actively flowing (reduced from 500ms)

	// After this many idle cycles, switch to idle polling
	idleThreshold = 5

	// Backoff constants for error handling
	initialBackoff = 1 * time.Second
	maxBackoff     = 30 * time.Second
	backoffFactor  = 2

	// Max consecutive errors before sending to errChan
	maxConsecutiveErrors = 5

	// Max seen event IDs to track (prevents unbounded memory growth)
	maxSeenEvents = 10000
)

// FetchLambdaFunctions retrieves all Lambda function names using AWS SDK
func FetchLambdaFunctions() ([]byte, error) {
	ctx := context.TODO()
	result, err := utils.LambdaClient.ListFunctions(ctx, &lambda.ListFunctionsInput{})
	if err != nil {
		return nil, err
	}

	// Format output to match old text format
	var output strings.Builder
	for _, fn := range result.Functions {
		output.WriteString(aws.ToString(fn.FunctionName))
		output.WriteString("\n")
	}

	return []byte(output.String()), nil
}

// ParseLogLine returns the raw log message without any processing
func ParseLogLine(line string) cloudwatch_model.LogEntry {
	return cloudwatch_model.LogEntry{
		Message: line,
	}
}

// StreamLambdaLogs streams logs from a Lambda function log group using AWS SDK.
// Uses adaptive polling, deduplication, and a goroutine pipeline for efficiency.
func StreamLambdaLogs(ctx context.Context, logGroupName string, logChan chan<- cloudwatch_model.LogEntry, errChan chan<- error) {
	// Internal channel: polling goroutine → processing goroutine
	rawChan := make(chan cwltypes.FilteredLogEvent, 200)

	var wg sync.WaitGroup

	// Goroutine 1: Polling — fetches raw events from CloudWatch
	wg.Add(1)
	go func() {
		defer wg.Done()
		defer close(rawChan)
		pollCloudWatchLogs(ctx, logGroupName, rawChan, errChan)
	}()

	// Goroutine 2: Processing — parses and dispatches log entries
	wg.Add(1)
	go func() {
		defer wg.Done()
		processLogEvents(ctx, rawChan, logChan)
	}()

	wg.Wait()
	close(logChan) // Close logChan when streaming completes
}

// pollCloudWatchLogs handles the CloudWatch API polling with adaptive intervals,
// deduplication, startTime advancement, and exponential backoff on errors.
func pollCloudWatchLogs(ctx context.Context, logGroupName string, rawChan chan<- cwltypes.FilteredLogEvent, errChan chan<- error) {
	// Start from NOW — true live tail, no historical logs
	startTime := time.Now().UnixMilli()

	input := &cloudwatchlogs.FilterLogEventsInput{
		LogGroupName: aws.String(logGroupName),
		StartTime:    aws.Int64(startTime),
	}

	// Deduplication: track seen event IDs
	seenEvents := make(map[string]struct{}, 256)

	// Adaptive polling state
	idleCount := 0
	currentInterval := activePollInterval

	// Error backoff state
	consecutiveErrors := 0
	currentBackoff := initialBackoff

	var nextToken *string

	for {
		select {
		case <-ctx.Done():
			return
		default:
		}

		// Apply pagination token if available
		if nextToken != nil {
			input.NextToken = nextToken
		} else {
			// When no pagination token, ensure we query from the latest startTime
			input.NextToken = nil
		}

		result, err := utils.LogsClient.FilterLogEvents(ctx, input)
		if err != nil {
			// Check if context was cancelled (client disconnected)
			if ctx.Err() != nil {
				return
			}

			consecutiveErrors++
			log.Printf("CloudWatch poll error (%d/%d): %v", consecutiveErrors, maxConsecutiveErrors, err)

			// After too many consecutive errors, notify the client
			if consecutiveErrors >= maxConsecutiveErrors {
				select {
				case errChan <- err:
				default:
				}
				return
			}

			// Exponential backoff on error
			select {
			case <-ctx.Done():
				return
			case <-time.After(currentBackoff):
			}
			currentBackoff = time.Duration(float64(currentBackoff) * backoffFactor)
			if currentBackoff > maxBackoff {
				currentBackoff = maxBackoff
			}
			continue
		}

		// Successful poll — reset error state
		consecutiveErrors = 0
		currentBackoff = initialBackoff

		// Track the maximum timestamp seen in this batch
		newEventsCount := 0
		maxTimestamp := startTime

		for _, event := range result.Events {
			eventID := aws.ToString(event.EventId)
			if eventID == "" {
				continue
			}

			// Deduplication check
			if _, seen := seenEvents[eventID]; seen {
				continue
			}
			seenEvents[eventID] = struct{}{}

			// Track max timestamp for startTime advancement
			if event.Timestamp != nil && *event.Timestamp > maxTimestamp {
				maxTimestamp = *event.Timestamp
			}

			newEventsCount++

			// Send raw event to processing goroutine
			select {
			case <-ctx.Done():
				return
			case rawChan <- event:
			}
		}

		// Handle pagination
		nextToken = result.NextToken

		// Advance startTime after processing events to avoid re-fetching
		if newEventsCount > 0 {
			// Advance startTime to (max seen timestamp + 1ms) to avoid re-fetching
			startTime = maxTimestamp + 1
			input.StartTime = aws.Int64(startTime)
		}

		// Prune seen events map if it grows too large
		if len(seenEvents) > maxSeenEvents {
			seenEvents = make(map[string]struct{}, 256)
		}

		// Adaptive polling: adjust interval based on activity
		if newEventsCount > 0 {
			// Logs are flowing — poll faster
			idleCount = 0
			currentInterval = activePollInterval
		} else if nextToken == nil {
			// No new events and no more pages — increment idle counter
			idleCount++
			if idleCount >= idleThreshold {
				currentInterval = idlePollInterval
			}
		}

		// Wait before next poll (skip wait if there are more pages to fetch)
		if nextToken == nil {
			select {
			case <-ctx.Done():
				return
			case <-time.After(currentInterval):
			}
		}
	}
}

// processLogEvents reads raw CloudWatch events and dispatches parsed LogEntry
// objects to the output channel. Runs in its own goroutine.
func processLogEvents(ctx context.Context, rawChan <-chan cwltypes.FilteredLogEvent, logChan chan<- cloudwatch_model.LogEntry) {
	for {
		select {
		case <-ctx.Done():
			return
		case event, ok := <-rawChan:
			if !ok {
				// rawChan closed, polling goroutine exited
				return
			}

			message := aws.ToString(event.Message)
			if message == "" {
				continue
			}

			entry := ParseLogLine(message)
			// Attach CloudWatch metadata
			if event.Timestamp != nil {
				entry.Timestamp = *event.Timestamp
			}
			if event.EventId != nil {
				entry.EventID = *event.EventId
			}

			select {
			case <-ctx.Done():
				return
			case logChan <- entry:
			}
		}
	}
}
