package cloudwatch

import (
	"os"
	"sync"
	"time"
)

// LogSession tracks active log streaming sessions
type LogSession struct {
	SessionID    string
	FunctionName string
	FilePath     string
	File         *os.File
	Mutex        sync.Mutex
	CreatedAt    time.Time
	LastAccess   time.Time
	LogCount     int
}
