package cloudwatch

// LogEntry represents a parsed log entry with color information
type LogEntry struct {
	Message   string
	Color     string
	Timestamp int64  // milliseconds since epoch from CloudWatch
	EventID   string // unique event ID from CloudWatch for deduplication
}
