package user

import (
	"context"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/iam"
)

func ListAccessKeysForUserModel(username string) {
	utils.ShowProcessingAnimation("Listing access keys for user: " + username)

	ctx := context.TODO()
	_, err := utils.IAMClient.ListAccessKeys(ctx, &iam.ListAccessKeysInput{
		UserName: aws.String(username),
	})

	utils.StopAnimation()

	if err != nil {
		println("Error listing access keys:", err.Error())
		return
	}
}
