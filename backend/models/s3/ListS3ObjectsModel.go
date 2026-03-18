package s3

import (
	"context"
	"fmt"
	"strings"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

func S3ListBucketObjects(bucketName string) (string, error) {
	client := utils.GetS3Client()
	ctx := context.TODO()

	input := &s3.ListObjectsV2Input{
		Bucket: &bucketName,
	}

	result, err := client.ListObjectsV2(ctx, input)

	// Handle errors
	if err != nil {
		if strings.Contains(err.Error(), "NoSuchBucket") {
			return "", fmt.Errorf("the specified bucket '%s' does not exist", bucketName)
		} else {
			return "", fmt.Errorf("error fetching objects: %v", err)
		}
	}

	// Empty bucket
	if len(result.Contents) == 0 {
		return "No objects found in bucket '" + bucketName + "'.", nil
	}

	// Format output to match AWS CLI format
	var lines []string
	for _, obj := range result.Contents {
		lastModified := ""
		size := int64(0)
		key := ""

		if obj.LastModified != nil {
			lastModified = obj.LastModified.Format("2006-01-02 15:04:05")
		}
		if obj.Size != nil {
			size = *obj.Size
		}
		if obj.Key != nil {
			key = *obj.Key
		}

		line := fmt.Sprintf("%s %10d %s", lastModified, size, key)
		lines = append(lines, line)
	}

	// Return the data
	return strings.Join(lines, "\n"), nil
}
