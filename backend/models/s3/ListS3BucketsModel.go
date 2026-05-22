package s3

import (
	"context"
	"fmt"
	"strings"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

// ListS3BucketsModel lists all S3 buckets
func ListS3BucketsModel() string {
	client := utils.GetS3Client()
	ctx := context.TODO()

	input := &s3.ListBucketsInput{}
	result, err := client.ListBuckets(ctx, input)
	if err != nil {
		return err.Error()
	}

	var output strings.Builder
	for _, bucket := range result.Buckets {
		bucketName := ""
		creationDate := ""

		if bucket.Name != nil {
			bucketName = *bucket.Name
		}
		if bucket.CreationDate != nil {
			creationDate = bucket.CreationDate.Format("2006-01-02 15:04:05")
		}

		output.WriteString(fmt.Sprintf("%s %s\n", creationDate, bucketName))
	}

	return output.String()
}
