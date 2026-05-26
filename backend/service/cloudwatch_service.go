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

// dedupCache implements a rolling FIFO cache for event ID deduplication with bounded memory
type dedupCache struct {
	seen map[string]struct{}
	fifo []string
	max  int
}

func newDedupCache(max int) *dedupCache {
	return &dedupCache{
		seen: make(map[string]struct{}, max),
		fifo: make([]string, 0, max),
		max:  max,
	}
}

func (c *dedupCache) Add(id string) bool {
	if _, exists := c.seen[id]; exists {
		return false // Already seen
	}
	c.seen[id] = struct{}{}
	c.fifo = append(c.fifo, id)

	if len(c.fifo) > c.max {
		oldest := c.fifo[0]
		c.fifo = c.fifo[1:]
		delete(c.seen, oldest)
	}
	return true
}

// Singleflight Shared Stream observable registry
type sharedStream struct {
	mu         sync.RWMutex
	logChan    chan cloudwatch_model.LogEntry
	clients    map[chan<- cloudwatch_model.LogEntry]struct{}
	cancelFunc context.CancelFunc
}

var (
	activeStreams      = make(map[string]*sharedStream)
	activeStreamsMutex sync.Mutex
)

// StreamLambdaLogs streams logs from a Lambda function log group using AWS SDK.
// It tries native StartLiveTail stream first and falls back to Singleflight Adaptive Polling on error.
func StreamLambdaLogs(ctx context.Context, logGroupName string, logChan chan<- cloudwatch_model.LogEntry, errChan chan<- error) {
	// 1. Try Native AWS StartLiveTail stream first
	log.Printf("Attempting native HTTP/2 StartLiveTail stream for log group: %s", logGroupName)
	err := streamLiveTailNative(ctx, logGroupName, logChan)
	if err == nil {
		log.Printf("Native StartLiveTail completed normally for: %s", logGroupName)
		close(logChan)
		return
	}

	if ctx.Err() != nil {
		close(logChan)
		return
	}

	log.Printf("Native StartLiveTail not supported or failed (%v). Falling back to optimized Adaptive Polling...", err)

	// 2. Fallback to Shared Singleflight Adaptive Polling stream
	streamLambdaLogsFallback(ctx, logGroupName, logChan, errChan)
}

// streamLiveTailNative initiates and consumes the native AWS StartLiveTail HTTP/2 stream
func streamLiveTailNative(ctx context.Context, logGroupName string, logChan chan<- cloudwatch_model.LogEntry) error {
	input := &cloudwatchlogs.StartLiveTailInput{
		LogGroupIdentifiers: []string{logGroupName},
	}

	output, err := utils.LogsClient.StartLiveTail(ctx, input)
	if err != nil {
		return err
	}

	stream := output.GetStream()
	defer stream.Close()

	eventsChan := stream.Events()

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case event, ok := <-eventsChan:
			if !ok {
				if err := stream.Err(); err != nil {
					return err
				}
				return nil
			}

			switch e := event.(type) {
			case *cwltypes.StartLiveTailResponseStreamMemberSessionStart:
				log.Printf("StartLiveTail native stream session started for log group: %s", logGroupName)
			case *cwltypes.StartLiveTailResponseStreamMemberSessionUpdate:
				for _, sessionResult := range e.Value.SessionResults {
					message := aws.ToString(sessionResult.Message)
					if message == "" {
						continue
					}

					entry := ParseLogLine(message)
					if sessionResult.Timestamp != nil {
						entry.Timestamp = *sessionResult.Timestamp
					}

					select {
					case <-ctx.Done():
						return ctx.Err()
					case logChan <- entry:
					}
				}
			}
		}
	}
}

// streamLambdaLogsFallback implements singleflight polling fallback fanning out logs to all active readers
func streamLambdaLogsFallback(ctx context.Context, logGroupName string, logChan chan<- cloudwatch_model.LogEntry, errChan chan<- error) {
	activeStreamsMutex.Lock()
	stream, exists := activeStreams[logGroupName]
	if !exists {
		// Start exactly one background polling observable loop per log group
		sharedCtx, cancel := context.WithCancel(context.Background())
		stream = &sharedStream{
			logChan:    make(chan cloudwatch_model.LogEntry, 1000),
			clients:    make(map[chan<- cloudwatch_model.LogEntry]struct{}),
			cancelFunc: cancel,
		}
		activeStreams[logGroupName] = stream

		go runSharedPollingLoop(sharedCtx, logGroupName, stream, errChan)
	}

	// Register the reader's channel
	stream.mu.Lock()
	stream.clients[logChan] = struct{}{}
	stream.mu.Unlock()
	activeStreamsMutex.Unlock()

	defer func() {
		// Clean up on disconnect
		activeStreamsMutex.Lock()
		stream.mu.Lock()
		delete(stream.clients, logChan)
		clientCount := len(stream.clients)
		stream.mu.Unlock()

		if clientCount == 0 {
			// Wipe background polling loop once all readers exit
			stream.cancelFunc()
			delete(activeStreams, logGroupName)
		}
		activeStreamsMutex.Unlock()
		close(logChan)
	}()

	// Pipeline logs to client with fast non-blocking drops for slow consumers
	for {
		select {
		case <-ctx.Done():
			return
		case entry, ok := <-stream.logChan:
			if !ok {
				return
			}
			select {
			case logChan <- entry:
			default:
				// Slow consumer overflow prevention
			}
		}
	}
}

// runSharedPollingLoop runs single-instance Go polling pipelines
func runSharedPollingLoop(ctx context.Context, logGroupName string, stream *sharedStream, errChan chan<- error) {
	defer close(stream.logChan)

	rawChan := make(chan cwltypes.FilteredLogEvent, 500)
	parsedChan := make(chan cloudwatch_model.LogEntry, 500)

	var wg sync.WaitGroup

	// Fetcher loop
	wg.Add(1)
	go func() {
		defer wg.Done()
		defer close(rawChan)
		pollCloudWatchLogs(ctx, logGroupName, rawChan, errChan)
	}()

	// Parsing loop
	wg.Add(1)
	go func() {
		defer wg.Done()
		defer close(parsedChan)
		processLogEvents(ctx, rawChan, parsedChan)
	}()

	// Broadcaster
	wg.Add(1)
	go func() {
		defer wg.Done()
		for {
			select {
			case <-ctx.Done():
				return
			case entry, ok := <-parsedChan:
				if !ok {
					return
				}
				select {
				case stream.logChan <- entry:
				default:
				}
			}
		}
	}()

	wg.Wait()
}

// pollCloudWatchLogs handles CloudWatch polling with rolling deduplication, zero drops, and adaptive backoff
func pollCloudWatchLogs(ctx context.Context, logGroupName string, rawChan chan<- cwltypes.FilteredLogEvent, errChan chan<- error) {
	startTime := time.Now().UnixMilli()

	input := &cloudwatchlogs.FilterLogEventsInput{
		LogGroupName: aws.String(logGroupName),
		StartTime:    aws.Int64(startTime),
	}

	// Rolling FIFO deduplication cache (holds up to 5,000 seen Event IDs)
	dedup := newDedupCache(5000)

	idleCount := 0
	currentInterval := activePollInterval

	consecutiveErrors := 0
	currentBackoff := initialBackoff

	var nextToken *string

	for {
		select {
		case <-ctx.Done():
			return
		default:
		}

		if nextToken != nil {
			input.NextToken = nextToken
		} else {
			input.NextToken = nil
		}

		result, err := utils.LogsClient.FilterLogEvents(ctx, input)
		if err != nil {
			if ctx.Err() != nil {
				return
			}

			consecutiveErrors++
			log.Printf("CloudWatch fallback poll error (%d/%d): %v", consecutiveErrors, maxConsecutiveErrors, err)

			if consecutiveErrors >= maxConsecutiveErrors {
				select {
				case errChan <- err:
				default:
				}
				return
			}

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

		consecutiveErrors = 0
		currentBackoff = initialBackoff

		newEventsCount := 0
		maxTimestamp := startTime

		for _, event := range result.Events {
			eventID := aws.ToString(event.EventId)
			if eventID == "" {
				continue
			}

			// Rolling FIFO deduplication (zero log drop algorithm)
			if !dedup.Add(eventID) {
				continue
			}

			if event.Timestamp != nil && *event.Timestamp > maxTimestamp {
				maxTimestamp = *event.Timestamp
			}

			newEventsCount++

			select {
			case <-ctx.Done():
				return
			case rawChan <- event:
			}
		}

		nextToken = result.NextToken

		// ZERO DROPS: Keep StartTime exactly at maxTimestamp (no +1). 
		// The next poll will retrieve records starting exactly from maxTimestamp,
		// and dedupCache will cleanly filter out the duplicates.
		if newEventsCount > 0 {
			startTime = maxTimestamp
			input.StartTime = aws.Int64(startTime)
		}

		if newEventsCount > 0 {
			idleCount = 0
			currentInterval = activePollInterval
		} else if nextToken == nil {
			idleCount++
			if idleCount >= idleThreshold {
				currentInterval = idlePollInterval
			}
		}

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
func processLogEvents(ctx context.Context, rawChan <-chan cwltypes.FilteredLogEvent, logChan chan<- cloudwatch_model.LogEntry) {
	for {
		select {
		case <-ctx.Done():
			return
		case event, ok := <-rawChan:
			if !ok {
				return
			}

			message := aws.ToString(event.Message)
			if message == "" {
				continue
			}

			entry := ParseLogLine(message)
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
