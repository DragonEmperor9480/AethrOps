package user

import (
	"context"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/iam"
)

type UserDependencies struct {
	Groups          []string `json:"groups"`
	ManagedPolicies []string `json:"managed_policies"`
	InlinePolicies  []string `json:"inline_policies"`
	AccessKeys      []string `json:"access_keys"`
	HasLoginProfile bool     `json:"has_login_profile"`
}

// CheckUserDependencies checks what dependencies a user has
func CheckUserDependencies(username string) (*UserDependencies, error) {
	ctx := context.TODO()
	deps := &UserDependencies{}

	// Check if user exists
	_, err := utils.IAMClient.GetUser(ctx, &iam.GetUserInput{
		UserName: aws.String(username),
	})
	if err != nil {
		return nil, err
	}

	// Get groups
	groupsResult, _ := utils.IAMClient.ListGroupsForUser(ctx, &iam.ListGroupsForUserInput{
		UserName: aws.String(username),
	})
	for _, g := range groupsResult.Groups {
		deps.Groups = append(deps.Groups, aws.ToString(g.GroupName))
	}

	// Get attached managed policies
	policiesResult, _ := utils.IAMClient.ListAttachedUserPolicies(ctx, &iam.ListAttachedUserPoliciesInput{
		UserName: aws.String(username),
	})
	for _, p := range policiesResult.AttachedPolicies {
		deps.ManagedPolicies = append(deps.ManagedPolicies, aws.ToString(p.PolicyName))
	}

	// Get inline policies
	inlineResult, _ := utils.IAMClient.ListUserPolicies(ctx, &iam.ListUserPoliciesInput{
		UserName: aws.String(username),
	})
	for _, p := range inlineResult.PolicyNames {
		deps.InlinePolicies = append(deps.InlinePolicies, p)
	}

	// Get access keys
	keysResult, _ := utils.IAMClient.ListAccessKeys(ctx, &iam.ListAccessKeysInput{
		UserName: aws.String(username),
	})
	for _, k := range keysResult.AccessKeyMetadata {
		deps.AccessKeys = append(deps.AccessKeys, aws.ToString(k.AccessKeyId))
	}

	// Check login profile
	_, err = utils.IAMClient.GetLoginProfile(ctx, &iam.GetLoginProfileInput{
		UserName: aws.String(username),
	})
	deps.HasLoginProfile = (err == nil)

	return deps, nil
}

// HasDependencies checks if user has any dependencies
func (d *UserDependencies) HasDependencies() bool {
	return len(d.Groups) > 0 || len(d.ManagedPolicies) > 0 ||
		len(d.InlinePolicies) > 0 || len(d.AccessKeys) > 0 ||
		d.HasLoginProfile
}
