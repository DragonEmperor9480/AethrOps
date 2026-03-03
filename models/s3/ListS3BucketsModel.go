package s3

import (
	"context"
	"fmt"
	"strings"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

func ListS3BucketsModel() string {
	utils.ShowProcessingAnimation("Listing S3 Buckets")

	client := utils.GetS3Client()
	ctx := context.TODO()

	input := &s3.ListBucketsInput{}
	result, err := client.ListBuckets(ctx, input)
	if err != nil {
		utils.StopAnimation()
		println("Error listing S3 buckets:", err.Error())
		return err.Error()
	}
	utils.StopAnimation()

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
