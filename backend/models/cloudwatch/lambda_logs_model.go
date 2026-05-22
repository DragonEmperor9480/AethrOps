package cloudwatch

// LogEntry represents a parsed log entry
type LogEntry struct {
	Message   string
	Timestamp int64  // milliseconds since epoch from CloudWatch
	EventID   string // unique event ID from CloudWatch for deduplication
}
