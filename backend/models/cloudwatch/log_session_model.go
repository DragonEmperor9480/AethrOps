package cloudwatch

import (
	"os"
	"sync"
	"sync/atomic"
	"time"
)

// LogSession tracks active log streaming sessions.
// File, LastAccess and LogCount are guarded by Mutex. LogChan is never
// closed: the background writer stops when CancelFunc is called, so a late
// send can never panic.
type LogSession struct {
	SessionID    string
	FunctionName string
	FilePath     string
	File         *os.File
	Mutex        sync.Mutex
	CreatedAt    time.Time
	LastAccess   time.Time
	LogCount     int
	LogChan      chan LogEntry
	CancelFunc   func()
	WG           sync.WaitGroup
	// Streaming is true while an SSE stream is writing to the session; the
	// idle cleanup never removes such a session
	Streaming atomic.Bool
}
