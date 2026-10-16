package s3

import (
	"context"
	"fmt"
	"strings"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

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
