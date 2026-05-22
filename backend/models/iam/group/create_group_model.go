package group

import (
	"context"
	"fmt"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/service/iam"
)

// CreateIAMGroup creates a new IAM group
func CreateIAMGroup(groupname string) error {
	client := utils.GetIAMClient()
	ctx := context.TODO()

	input := &iam.CreateGroupInput{
		GroupName: &groupname,
	}

	_, err := client.CreateGroup(ctx, input)
	if err != nil {
		return fmt.Errorf("failed to create group: %w", err)
	}

	return nil
}
