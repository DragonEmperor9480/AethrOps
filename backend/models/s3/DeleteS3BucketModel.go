package s3

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"strings"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
)

func DeleteS3BucketModel(bucketName string) error {
	client := utils.GetS3Client()
	ctx := context.TODO()

	// Step 0: Check if bucket has objects
	listInput := &s3.ListObjectsV2Input{
		Bucket: &bucketName,
	}
	listResult, err := client.ListObjectsV2(ctx, listInput)
	if err != nil {
		return fmt.Errorf("failed to list objects: %w", err)
	}

	objectsExist := len(listResult.Contents) > 0

	if objectsExist {
		// Ask user confirmation
		reader := bufio.NewReader(os.Stdin)
		fmt.Printf("Bucket '%s' contains objects. Do you still want to delete it? (y/n): ", bucketName)
		confirm, _ := reader.ReadString('\n')
		confirm = strings.TrimSpace(strings.ToLower(confirm))
		if confirm != "y" {
			fmt.Println("Operation cancelled. Bucket not deleted.")
			return nil
		}
	}

	utils.ShowProcessingAnimation("Deleting S3 bucket: " + bucketName)

	// 1. Remove all objects (non-versioned bucket)
	if objectsExist {
		var objectsToDelete []types.ObjectIdentifier
		for _, obj := range listResult.Contents {
			objectsToDelete = append(objectsToDelete, types.ObjectIdentifier{
				Key: obj.Key,
			})
		}

		if len(objectsToDelete) > 0 {
			deleteInput := &s3.DeleteObjectsInput{
				Bucket: &bucketName,
				Delete: &types.Delete{
					Objects: objectsToDelete,
				},
			}
			_, err := client.DeleteObjects(ctx, deleteInput)
			if err != nil {
				utils.StopAnimation()
				return fmt.Errorf("failed to empty bucket (objects deletion error): %w", err)
			}
		}
	}

	// 2. Remove all versions if bucket is versioned
	versionsInput := &s3.ListObjectVersionsInput{
		Bucket: &bucketName,
	}
	versionsResult, verErr := client.ListObjectVersions(ctx, versionsInput)
	if verErr == nil && (len(versionsResult.Versions) > 0 || len(versionsResult.DeleteMarkers) > 0) {
		var versionsToDelete []types.ObjectIdentifier

		// Delete versions
		for _, v := range versionsResult.Versions {
			versionsToDelete = append(versionsToDelete, types.ObjectIdentifier{
				Key:       v.Key,
				VersionId: v.VersionId,
			})
		}

		// Delete markers
		for _, v := range versionsResult.DeleteMarkers {
			versionsToDelete = append(versionsToDelete, types.ObjectIdentifier{
				Key:       v.Key,
				VersionId: v.VersionId,
			})
		}

		if len(versionsToDelete) > 0 {
			deleteVersionsInput := &s3.DeleteObjectsInput{
				Bucket: &bucketName,
				Delete: &types.Delete{
					Objects: versionsToDelete,
				},
			}
			_, err := client.DeleteObjects(ctx, deleteVersionsInput)
			if err != nil {
				utils.StopAnimation()
				return fmt.Errorf("failed to delete versions: %w", err)
			}
		}
	}

	// 3. Delete bucket itself
	deleteBucketInput := &s3.DeleteBucketInput{
		Bucket: &bucketName,
	}
	_, delErr := client.DeleteBucket(ctx, deleteBucketInput)
	utils.StopAnimation()
	if delErr != nil {
		return fmt.Errorf("failed to delete bucket: %w", delErr)
	}

	return nil
}
