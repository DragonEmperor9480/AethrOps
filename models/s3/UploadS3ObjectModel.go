package s3

import (
	"context"
	"fmt"
	"os"
	"strings"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

// UploadS3Object uploads a file to S3
func UploadS3Object(bucketName, objectKey, filePath string) error {
	return UploadS3ObjectWithProgress(bucketName, objectKey, filePath, nil)
}

// UploadS3ObjectWithProgress uploads a file to S3 with progress tracking
func UploadS3ObjectWithProgress(bucketName, objectKey, filePath string, progressCallback ProgressCallback) error {
	client := utils.GetS3Client()
	ctx := context.TODO()

	// Open the file
	file, err := os.Open(filePath)
	if err != nil {
		return fmt.Errorf("failed to open file: %w", err)
	}
	defer file.Close()

	// Get file size
	fileInfo, err := file.Stat()
	if err != nil {
		return fmt.Errorf("failed to get file info: %w", err)
	}
	totalSize := fileInfo.Size()

	// Create progress reader if callback provided
	var body *os.File
	var progressBody *progressReader

	if progressCallback != nil {
		progressBody = &progressReader{
			reader:   file,
			callback: progressCallback,
			total:    totalSize,
		}
	} else {
		body = file
	}

	// Upload the file with ContentLength specified
	var input *s3.PutObjectInput
	if progressCallback != nil {
		input = &s3.PutObjectInput{
			Bucket:        &bucketName,
			Key:           &objectKey,
			Body:          progressBody,
			ContentLength: &totalSize,
		}
	} else {
		input = &s3.PutObjectInput{
			Bucket:        &bucketName,
			Key:           &objectKey,
			Body:          body,
			ContentLength: &totalSize,
		}
	}

	_, err = client.PutObject(ctx, input)
	if err != nil {
		return fmt.Errorf("failed to upload object: %w", err)
	}

	return nil
}

// CreateS3Folder creates a "folder" in S3 (empty object with / suffix)
func CreateS3Folder(bucketName, folderPath string) error {
	client := utils.GetS3Client()
	ctx := context.TODO()

	// Ensure folder path ends with /
	if !strings.HasSuffix(folderPath, "/") {
		folderPath += "/"
	}

	// Create empty object
	input := &s3.PutObjectInput{
		Bucket: &bucketName,
		Key:    &folderPath,
		Body:   nil,
	}

	_, err := client.PutObject(ctx, input)
	if err != nil {
		return fmt.Errorf("failed to create folder: %w", err)
	}

	return nil
}
