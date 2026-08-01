package service

import (
	"context"
	"fmt"
	"strings"

	"github.com/DragonEmperor9480/AethrOps/constants"
	"github.com/DragonEmperor9480/AethrOps/models"
	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/iam"
)

// CreateIAMGroup creates a new IAM group
func CreateIAMGroup(groupname string) (int, error) {
	client := utils.GetIAMClient()
	ctx := context.TODO()

	_, err := client.CreateGroup(ctx, &iam.CreateGroupInput{
		GroupName: &groupname,
	})
	if err != nil {
		if strings.Contains(err.Error(), "EntityAlreadyExists") {
			return constants.GroupAlreadyExists, nil
		}
		return constants.GroupCreationError, err
	}

	return constants.GroupCreatedSuccess, nil
}

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
			return err
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

func CheckGroupDependencies(groupname string) (*models.GroupDependencies, error) {
	client := utils.GetIAMClient()
	ctx := context.TODO()

	deps := &models.GroupDependencies{
		Users:            []string{},
		AttachedPolicies: []string{},
	}

	// Get group and its users
	getGroupInput := &iam.GetGroupInput{
		GroupName: &groupname,
	}
	getGroupOutput, err := client.GetGroup(ctx, getGroupInput)
	if err != nil {
		return nil, err
	}

	// Collect users
	for _, user := range getGroupOutput.Users {
		if user.UserName != nil {
			deps.Users = append(deps.Users, *user.UserName)
		}
	}

	// Get attached policies
	listPoliciesInput := &iam.ListAttachedGroupPoliciesInput{
		GroupName: &groupname,
	}
	policiesOutput, err := client.ListAttachedGroupPolicies(ctx, listPoliciesInput)
	if err != nil {
		return nil, err
	}

	for _, policy := range policiesOutput.AttachedPolicies {
		if policy.PolicyArn != nil {
			deps.AttachedPolicies = append(deps.AttachedPolicies, *policy.PolicyArn)
		}
	}

	return deps, nil
}

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
		return err
	}

	return nil
}

// AddUserToGroupModel adds a user to a group
func AddUserToGroupModel(username, groupname string) error {
	ctx := context.TODO()
	_, err := utils.IAMClient.AddUserToGroup(ctx, &iam.AddUserToGroupInput{
		UserName:  aws.String(username),
		GroupName: aws.String(groupname),
	})

	if err != nil {
		return err
	}

	return nil
}

// ListUsersInGroupModel lists all users in a group
func ListUsersInGroupModel(groupname string) ([]models.UserInGroup, error) {
	client := utils.GetIAMClient()
	ctx := context.TODO()

	input := &iam.GetGroupInput{
		GroupName: &groupname,
	}

	result, err := client.GetGroup(ctx, input)
	if err != nil {
		return nil, fmt.Errorf("failed to get group: %w", err)
	}

	users := make([]models.UserInGroup, 0, len(result.Users))
	for _, user := range result.Users {
		users = append(users, models.UserInGroup{
			UserName:   aws.ToString(user.UserName),
			UserID:     aws.ToString(user.UserId),
			CreateDate: user.CreateDate.String(),
		})
	}

	return users, nil
}

func ListUserGroupsModel(username string) []string {
	client := utils.GetIAMClient()
	ctx := context.TODO()

	input := &iam.ListGroupsForUserInput{
		UserName: &username,
	}

	result, err := client.ListGroupsForUser(ctx, input)
	if err != nil {
		return []string{}
	}

	var groupNames []string
	for _, group := range result.Groups {
		if group.GroupName != nil {
			groupNames = append(groupNames, *group.GroupName)
		}
	}

	return groupNames
}
