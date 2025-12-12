package cloudwatch

import (
	"context"
	"strings"
	"time"

	"github.com/DragonEmperor9480/aws_cli_manager/utils"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/cloudwatchlogs"
	"github.com/aws/aws-sdk-go-v2/service/lambda"
)

// LogEntry represents a parsed log entry with color information
type LogEntry struct {
	Message string
	Color   string
}

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
func ParseLogLine(line string) LogEntry {
	// Return raw message as-is, no parsing or color coding
	return LogEntry{
		Message: line,
		Color:   "white",
	}
}

// StreamLambdaLogs streams logs from a Lambda function log group using AWS SDK
func StreamLambdaLogs(ctx context.Context, logGroupName string, logChan chan<- LogEntry, errChan chan<- error) {
	// Use current time as start - only show NEW logs from NOW onwards (true live tail)
	// CloudWatch uses milliseconds, so multiply by 1000
	startTime := time.Now().Unix() * 1000

	input := &cloudwatchlogs.FilterLogEventsInput{
		LogGroupName: aws.String(logGroupName),
		StartTime:    aws.Int64(startTime), // Start from NOW, not from beginning
	}

	// Poll for new events continuously (no initial fetch of old logs)
	var nextToken *string
	for {
		select {
		case <-ctx.Done():
			return
		default:
			if nextToken != nil {
				input.NextToken = nextToken
			}

			result, err := utils.LogsClient.FilterLogEvents(ctx, input)
			if err != nil {
				continue // Ignore errors and keep trying
			}

			for _, event := range result.Events {
				message := aws.ToString(event.Message)
				if message == "" {
					continue
				}
				select {
				case <-ctx.Done():
					return
				case logChan <- ParseLogLine(message):
				}
			}

			nextToken = result.NextToken
		}
	}
}
