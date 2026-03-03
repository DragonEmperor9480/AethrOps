package s3

import (
	"context"
	"fmt"
	"strings"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

func CreateS3BucketModel(bucketname string) {
	utils.ShowProcessingAnimation("Creating S3 bucket: " + bucketname)

	client := utils.GetS3Client()
	ctx := context.TODO()

	input := &s3.CreateBucketInput{
		Bucket: &bucketname,
	}

	_, err := client.CreateBucket(ctx, input)
	utils.StopAnimation()

	if err != nil {
		if strings.Contains(err.Error(), "BucketAlreadyExists") || strings.Contains(err.Error(), "BucketAlreadyOwnedByYou") {
			fmt.Println(utils.Bold + utils.Yellow + "Bucket '" + bucketname + "' already exists!" + utils.Reset)
		} else {
			fmt.Println(utils.Bold + utils.Red + "Error creating S3 bucket: " + err.Error() + utils.Reset)
		}
		return
	}

	fmt.Println(utils.Bold + utils.Green + "S3 bucket '" + bucketname + "' created successfully!" + utils.Reset)
}
