package s3

import (
	"context"
	"fmt"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

// CreateS3BucketModel creates an S3 bucket
func CreateS3BucketModel(bucketname string) error {
	client := utils.GetS3Client()
	ctx := context.TODO()

	input := &s3.CreateBucketInput{
		Bucket: &bucketname,
	}

	_, err := client.CreateBucket(ctx, input)
	if err != nil {
		return fmt.Errorf("failed to create bucket: %w", err)
	}

	return nil
}
