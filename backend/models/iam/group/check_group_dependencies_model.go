package group

import (
	"context"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/service/iam"
)

type GroupDependencies struct {
	Users            []string `json:"users"`
	AttachedPolicies []string `json:"attached_policies"`
}

func CheckGroupDependencies(groupname string) (*GroupDependencies, error) {
	client := utils.GetIAMClient()
	ctx := context.TODO()

	deps := &GroupDependencies{
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
