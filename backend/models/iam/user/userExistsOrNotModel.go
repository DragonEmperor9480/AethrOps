package user

import (
	"context"
	"strings"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/iam"
)

func UserExistsOrNotModel(username string) bool {
	ctx := context.TODO()

	_, err := utils.IAMClient.GetUser(ctx, &iam.GetUserInput{
		UserName: aws.String(username),
	})

	if err != nil {
		if strings.Contains(err.Error(), "NoSuchEntity") {
			return false
		}
		// Other errors also mean user doesn't exist or can't be accessed
		return false
	}
	return true
}
