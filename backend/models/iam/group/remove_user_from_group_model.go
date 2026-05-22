package group

import (
	"context"
	"fmt"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/service/iam"
)

// RemoveUserFromGroupModel removes a user from a group
func RemoveUserFromGroupModel(username, groupname string) error {
	client := utils.GetIAMClient()
	ctx := context.TODO()

	input := &iam.RemoveUserFromGroupInput{
		GroupName: &groupname,
		UserName:  &username,
	}

	_, err := client.RemoveUserFromGroup(ctx, input)
	if err != nil {
		return fmt.Errorf("failed to remove user from group: %w", err)
	}

	return nil
}
