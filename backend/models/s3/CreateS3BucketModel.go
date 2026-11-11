package s3

import (
	"context"
	"fmt"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
)

// CreateS3BucketModel creates an S3 bucket in the account's region (the
// region the S3 client is configured for).
func CreateS3BucketModel(bucketname string) error {
	client := utils.GetS3Client()
	ctx := context.TODO()

	input := &s3.CreateBucketInput{
		Bucket: &bucketname,
	}

	// Outside us-east-1, S3 requires the region as LocationConstraint and
	// rejects the request without it (IllegalLocationConstraintException).
	// us-east-1 is the one region where it must be left out.
	if region := client.Options().Region; region != "" && region != "us-east-1" {
		input.CreateBucketConfiguration = &types.CreateBucketConfiguration{
			LocationConstraint: types.BucketLocationConstraint(region),
		}
	}

	_, err := client.CreateBucket(ctx, input)
	if err != nil {
		return fmt.Errorf("failed to create bucket: %w", err)
	}

	return nil
}
