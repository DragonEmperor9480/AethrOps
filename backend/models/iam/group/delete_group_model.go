package group

import (
	"context"
	"fmt"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/service/iam"
)

// DeleteGroupModel deletes a group (simple version without dependency cleanup)
func DeleteGroupModel(groupname string) error {
	client := utils.GetIAMClient()
	ctx := context.TODO()

	// Delete group
	deleteInput := &iam.DeleteGroupInput{
		GroupName: &groupname,
	}
	_, err := client.DeleteGroup(ctx, deleteInput)
	if err != nil {
		return fmt.Errorf("failed to delete group: %w", err)
	}

	return nil
}
