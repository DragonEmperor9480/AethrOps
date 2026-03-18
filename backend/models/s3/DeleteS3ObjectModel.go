package s3

import (
	"context"
	"fmt"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

// DeleteS3Object deletes an object from S3
func DeleteS3Object(bucketName, objectKey string) error {
	client := utils.GetS3Client()
	ctx := context.TODO()

	input := &s3.DeleteObjectInput{
		Bucket: &bucketName,
		Key:    &objectKey,
	}

	_, err := client.DeleteObject(ctx, input)
	if err != nil {
		return fmt.Errorf("failed to delete object: %w", err)
	}

	return nil
}
