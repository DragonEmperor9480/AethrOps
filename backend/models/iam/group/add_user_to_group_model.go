package group

import (
	"context"
	"fmt"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/iam"
)

// AddUserToGroupModel adds a user to a group
func AddUserToGroupModel(username, groupname string) error {
	ctx := context.TODO()
	_, err := utils.IAMClient.AddUserToGroup(ctx, &iam.AddUserToGroupInput{
		UserName:  aws.String(username),
		GroupName: aws.String(groupname),
	})

	if err != nil {
		return fmt.Errorf("failed to add user to group: %w", err)
	}

	return nil
}
