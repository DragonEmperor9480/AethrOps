package user

import (
	"context"
	"fmt"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/iam"
)

// UpdateUserPasswordModel updates a user's password
func UpdateUserPasswordModel(username, password string) error {
	ctx := context.TODO()
	_, err := utils.IAMClient.UpdateLoginProfile(ctx, &iam.UpdateLoginProfileInput{
		UserName: aws.String(username),
		Password: aws.String(password),
	})

	if err != nil {
		return fmt.Errorf("failed to update password: %w", err)
	}

	return nil
}
