package s3

import "io"

// ProgressCallback is a function type for progress updates
type ProgressCallback func(bytesTransferred, totalBytes int64)

// progressReader wraps an io.Reader to track progress
type progressReader struct {
	reader      io.Reader
	callback    ProgressCallback
	total       int64
	transferred int64
}

func (pr *progressReader) Read(p []byte) (int, error) {
	n, err := pr.reader.Read(p)
	pr.transferred += int64(n)
	if pr.callback != nil {
		pr.callback(pr.transferred, pr.total)
	}
	return n, err
}
