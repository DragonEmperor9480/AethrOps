package group

import (
	"context"
	"fmt"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/service/iam"
)

func ForceDeleteGroup(groupname string) error {
	client := utils.GetIAMClient()
	ctx := context.TODO()

	// Get group dependencies
	deps, err := CheckGroupDependencies(groupname)
	if err != nil {
		return err
	}

	// Detach all policies
	for _, policyArn := range deps.AttachedPolicies {
		detachInput := &iam.DetachGroupPolicyInput{
			GroupName: &groupname,
			PolicyArn: &policyArn,
		}
		_, err := client.DetachGroupPolicy(ctx, detachInput)
		if err != nil {
			return fmt.Errorf("failed to detach policy %s: %w", policyArn, err)
		}
	}

	// Remove all users from group
	for _, username := range deps.Users {
		removeUserInput := &iam.RemoveUserFromGroupInput{
			GroupName: &groupname,
			UserName:  &username,
		}
		_, err := client.RemoveUserFromGroup(ctx, removeUserInput)
		if err != nil {
			return fmt.Errorf("failed to remove user %s: %w", username, err)
		}
	}

	// Delete the group
	deleteInput := &iam.DeleteGroupInput{
		GroupName: &groupname,
	}
	_, err = client.DeleteGroup(ctx, deleteInput)
	if err != nil {
		return fmt.Errorf("failed to delete group: %w", err)
	}

	return nil
}
