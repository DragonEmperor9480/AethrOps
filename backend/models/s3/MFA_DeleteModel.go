package s3

import (
	"context"
	"fmt"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
)

// GetBucketVersioning gets current versioning + MFA status
func GetBucketVersioning(bucket string) string {
	client := utils.GetS3Client()
	ctx := context.TODO()

	input := &s3.GetBucketVersioningInput{
		Bucket: &bucket,
	}

	result, err := client.GetBucketVersioning(ctx, input)
	if err != nil {
		return fmt.Sprintf("Error: %s", err.Error())
	}

	output := fmt.Sprintf("Status: %s\nMFADelete: %s\n", result.Status, result.MFADelete)
	return output
}

// UpdateBucketMFADelete updates MFA Delete config
func UpdateBucketMFADelete(bucket, securityARN, mfaCode string, enable bool) error {
	client := utils.GetS3Client()
	ctx := context.TODO()

	var mfaDelete types.MFADelete
	if enable {
		mfaDelete = types.MFADeleteEnabled
	} else {
		mfaDelete = types.MFADeleteDisabled
	}

	// Format: "serial-number token-code" (space-separated)
	mfaString := fmt.Sprintf("%s %s", securityARN, mfaCode)

	input := &s3.PutBucketVersioningInput{
		Bucket: &bucket,
		VersioningConfiguration: &types.VersioningConfiguration{
			Status:    types.BucketVersioningStatusEnabled,
			MFADelete: mfaDelete,
		},
		MFA: &mfaString,
	}

	_, err := client.PutBucketVersioning(ctx, input)
	if err != nil {
		return fmt.Errorf("failed to update MFA delete: %w", err)
	}

	return nil
}
