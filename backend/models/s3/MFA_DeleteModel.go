package s3

import (
	"context"
	"fmt"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
)

// Get current versioning + MFA status
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

// Update MFA Delete config
func UpdateBucketMFADelete(bucket, securityARN, mfaCode string, enable bool) error {
	utils.ShowProcessingAnimation("Updating MFA Delete setting...")

	client := utils.GetS3Client()
	ctx := context.TODO()

	var mfaDelete types.MFADelete
	actionMsg := "disabled"
	if enable {
		mfaDelete = types.MFADeleteEnabled
		actionMsg = "enabled"
	} else {
		mfaDelete = types.MFADeleteDisabled
	}

	// Format: "serial-number token-code" (space-separated)
	mfaString := fmt.Sprintf("%s %s", securityARN, mfaCode)

	// Debug logging
	fmt.Printf("Debug - MFA String: %s\n", mfaString)
	fmt.Printf("Debug - Device ARN: %s\n", securityARN)
	fmt.Printf("Debug - MFA Code: %s (length: %d)\n", mfaCode, len(mfaCode))
	fmt.Printf("Debug - Enable: %v\n", enable)

	input := &s3.PutBucketVersioningInput{
		Bucket: &bucket,
		VersioningConfiguration: &types.VersioningConfiguration{
			Status:    types.BucketVersioningStatusEnabled,
			MFADelete: mfaDelete,
		},
		MFA: &mfaString,
	}

	_, err := client.PutBucketVersioning(ctx, input)
	utils.StopAnimation()

	if err != nil {
		fmt.Println(utils.Red + "Failed to update MFA Delete:" + utils.Reset)
		fmt.Printf("Error details: %v\n", err)
		return fmt.Errorf("failed to update MFA delete: %v", err)
	}

	fmt.Println(utils.Green + "MFA Delete successfully " + actionMsg + " for bucket '" + bucket + "'." + utils.Reset)
	return nil
}
