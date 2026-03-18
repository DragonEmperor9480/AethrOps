package s3

import (
	"context"
	"fmt"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
)

// Get current bucket versioning status (Enabled, Suspended, or empty if never set)
func GetBucketVersioningStatusModel(bucketName string) (string, error) {
	utils.ShowProcessingAnimation("Checking versioning status for bucket: " + bucketName)

	client := utils.GetS3Client()
	ctx := context.TODO()

	input := &s3.GetBucketVersioningInput{
		Bucket: &bucketName,
	}

	result, err := client.GetBucketVersioning(ctx, input)
	if err != nil {
		utils.StopAnimation()
		return "", err
	}
	utils.StopAnimation()
	fmt.Println()

	return string(result.Status), nil
}

func SetBucketVersioningModel(bucketName, status string) error {
	client := utils.GetS3Client()
	ctx := context.TODO()

	var versioningStatus types.BucketVersioningStatus
	if status == "Enabled" {
		versioningStatus = types.BucketVersioningStatusEnabled
	} else if status == "Suspended" {
		versioningStatus = types.BucketVersioningStatusSuspended
	} else {
		return fmt.Errorf("invalid status: %s (must be 'Enabled' or 'Suspended')", status)
	}

	input := &s3.PutBucketVersioningInput{
		Bucket: &bucketName,
		VersioningConfiguration: &types.VersioningConfiguration{
			Status: versioningStatus,
		},
	}

	_, err := client.PutBucketVersioning(ctx, input)
	if err != nil {
		return fmt.Errorf("failed to set versioning: %w", err)
	}
	return nil
}
