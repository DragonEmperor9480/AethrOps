package service

import (
	"context"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/iam"
	iamtypes "github.com/aws/aws-sdk-go-v2/service/iam/types"
)

// IAM list APIs return at most 100 items per page. These helpers follow the
// pagination markers so callers always see the complete list.

// ListAllIAMUsers returns every IAM user in the account.
func ListAllIAMUsers(ctx context.Context) ([]iamtypes.User, error) {
	var users []iamtypes.User
	p := iam.NewListUsersPaginator(utils.IAMClient, &iam.ListUsersInput{})
	for p.HasMorePages() {
		page, err := p.NextPage(ctx)
		if err != nil {
			return nil, err
		}
		users = append(users, page.Users...)
	}
	return users, nil
}

// ListAllIAMGroups returns every IAM group in the account.
func ListAllIAMGroups(ctx context.Context) ([]iamtypes.Group, error) {
	var groups []iamtypes.Group
	p := iam.NewListGroupsPaginator(utils.IAMClient, &iam.ListGroupsInput{})
	for p.HasMorePages() {
		page, err := p.NextPage(ctx)
		if err != nil {
			return nil, err
		}
		groups = append(groups, page.Groups...)
	}
	return groups, nil
}

// listGroupsForUser returns every group the user belongs to.
func listGroupsForUser(ctx context.Context, username string) ([]iamtypes.Group, error) {
	var groups []iamtypes.Group
	p := iam.NewListGroupsForUserPaginator(utils.IAMClient, &iam.ListGroupsForUserInput{
		UserName: aws.String(username),
	})
	for p.HasMorePages() {
		page, err := p.NextPage(ctx)
		if err != nil {
			return nil, err
		}
		groups = append(groups, page.Groups...)
	}
	return groups, nil
}

// listAttachedUserPolicies returns every managed policy attached to the user.
func listAttachedUserPolicies(ctx context.Context, username string) ([]iamtypes.AttachedPolicy, error) {
	var policies []iamtypes.AttachedPolicy
	p := iam.NewListAttachedUserPoliciesPaginator(utils.IAMClient, &iam.ListAttachedUserPoliciesInput{
		UserName: aws.String(username),
	})
	for p.HasMorePages() {
		page, err := p.NextPage(ctx)
		if err != nil {
			return nil, err
		}
		policies = append(policies, page.AttachedPolicies...)
	}
	return policies, nil
}

// listUserPolicyNames returns the names of every inline policy on the user.
func listUserPolicyNames(ctx context.Context, username string) ([]string, error) {
	var names []string
	p := iam.NewListUserPoliciesPaginator(utils.IAMClient, &iam.ListUserPoliciesInput{
		UserName: aws.String(username),
	})
	for p.HasMorePages() {
		page, err := p.NextPage(ctx)
		if err != nil {
			return nil, err
		}
		names = append(names, page.PolicyNames...)
	}
	return names, nil
}

// listGroupUsers returns every member of the group.
func listGroupUsers(ctx context.Context, groupname string) ([]iamtypes.User, error) {
	var users []iamtypes.User
	p := iam.NewGetGroupPaginator(utils.IAMClient, &iam.GetGroupInput{
		GroupName: aws.String(groupname),
	})
	for p.HasMorePages() {
		page, err := p.NextPage(ctx)
		if err != nil {
			return nil, err
		}
		users = append(users, page.Users...)
	}
	return users, nil
}

// listAttachedGroupPolicies returns every managed policy attached to the group.
func listAttachedGroupPolicies(ctx context.Context, groupname string) ([]iamtypes.AttachedPolicy, error) {
	var policies []iamtypes.AttachedPolicy
	p := iam.NewListAttachedGroupPoliciesPaginator(utils.IAMClient, &iam.ListAttachedGroupPoliciesInput{
		GroupName: aws.String(groupname),
	})
	for p.HasMorePages() {
		page, err := p.NextPage(ctx)
		if err != nil {
			return nil, err
		}
		policies = append(policies, page.AttachedPolicies...)
	}
	return policies, nil
}
