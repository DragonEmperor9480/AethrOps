package s3

import (
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

// DownloadS3Object downloads an object from S3 bucket
// Returns the file data as bytes and error
func DownloadS3Object(bucketName, objectKey string) ([]byte, error) {
	client := utils.GetS3Client()
	ctx := context.TODO()

	input := &s3.GetObjectInput{
		Bucket: &bucketName,
		Key:    &objectKey,
	}

	result, err := client.GetObject(ctx, input)
	if err != nil {
		return nil, fmt.Errorf("failed to download object: %w", err)
	}
	defer result.Body.Close()

	// Read the entire object into memory
	data, err := io.ReadAll(result.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read object data: %w", err)
	}

	return data, nil
}

// DownloadS3ObjectToFile downloads an object from S3 and saves it to a local file
// This is useful for CLI where we want to save directly to disk
func DownloadS3ObjectToFile(bucketName, objectKey, destinationPath string) error {
	return DownloadS3ObjectToFileWithProgress(bucketName, objectKey, destinationPath, nil)
}

// DownloadS3ObjectToFileWithProgress downloads with progress callback
func DownloadS3ObjectToFileWithProgress(bucketName, objectKey, destinationPath string, progressCallback ProgressCallback) error {
	client := utils.GetS3Client()
	ctx := context.TODO()

	input := &s3.GetObjectInput{
		Bucket: &bucketName,
		Key:    &objectKey,
	}

	result, err := client.GetObject(ctx, input)
	if err != nil {
		return fmt.Errorf("failed to download object: %w", err)
	}
	defer result.Body.Close()

	// Get total size
	totalSize := int64(0)
	if result.ContentLength != nil {
		totalSize = *result.ContentLength
	}

	// Create destination directory if it doesn't exist
	destDir := filepath.Dir(destinationPath)
	if err := os.MkdirAll(destDir, 0750); err != nil {
		return fmt.Errorf("failed to create destination directory: %w", err)
	}

	// Create the destination file
	outFile, err := os.Create(destinationPath)
	if err != nil {
		return fmt.Errorf("failed to create destination file: %w", err)
	}
	defer outFile.Close()

	// Copy with progress tracking
	var bytesWritten int64
	if progressCallback != nil {
		reader := &progressReader{
			reader:   result.Body,
			callback: progressCallback,
			total:    totalSize,
		}
		bytesWritten, err = io.Copy(outFile, reader)
	} else {
		bytesWritten, err = io.Copy(outFile, result.Body)
	}

	if err != nil {
		return fmt.Errorf("failed to write object to file: %w", err)
	}

	// Verify the file was written
	if bytesWritten == 0 {
		return fmt.Errorf("no data written to file")
	}

	return nil
}

// GetObjectMetadata gets metadata about an S3 object without downloading it
func GetObjectMetadata(bucketName, objectKey string) (map[string]interface{}, error) {
	client := utils.GetS3Client()
	ctx := context.TODO()

	input := &s3.HeadObjectInput{
		Bucket: &bucketName,
		Key:    &objectKey,
	}

	result, err := client.HeadObject(ctx, input)
	if err != nil {
		return nil, fmt.Errorf("failed to get object metadata: %w", err)
	}

	metadata := map[string]interface{}{
		"content_length": result.ContentLength,
		"content_type":   result.ContentType,
		"last_modified":  result.LastModified,
		"etag":           result.ETag,
	}

	return metadata, nil
}
