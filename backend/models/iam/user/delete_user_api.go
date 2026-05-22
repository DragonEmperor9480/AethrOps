package user

import (
	"context"
	"strings"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/iam"
)

// DeleteIAMUserAPI deletes an IAM user without interactive prompts (for API use)
// It automatically removes all dependencies
func DeleteIAMUserAPI(username string) error {
	ctx := context.TODO()

	// Check if user exists
	_, err := utils.IAMClient.GetUser(ctx, &iam.GetUserInput{
		UserName: aws.String(username),
	})

	if err != nil {
		if strings.Contains(err.Error(), "NoSuchEntity") {
			return err
		}
		return err
	}

	// Get groups
	groupsResult, _ := utils.IAMClient.ListGroupsForUser(ctx, &iam.ListGroupsForUserInput{
		UserName: aws.String(username),
	})

	// Get attached managed policies
	policiesResult, _ := utils.IAMClient.ListAttachedUserPolicies(ctx, &iam.ListAttachedUserPoliciesInput{
		UserName: aws.String(username),
	})

	// Get inline policies
	inlineResult, _ := utils.IAMClient.ListUserPolicies(ctx, &iam.ListUserPoliciesInput{
		UserName: aws.String(username),
	})

	// Get access keys
	keysResult, _ := utils.IAMClient.ListAccessKeys(ctx, &iam.ListAccessKeysInput{
		UserName: aws.String(username),
	})

	// Remove user from all groups
	for _, g := range groupsResult.Groups {
		if _, err := utils.IAMClient.RemoveUserFromGroup(ctx, &iam.RemoveUserFromGroupInput{
			UserName:  aws.String(username),
			GroupName: g.GroupName,
		}); err != nil {
			// Continue cleanup even if one operation fails
			continue
		}
	}

	// Detach all managed policies
	for _, p := range policiesResult.AttachedPolicies {
		if _, err := utils.IAMClient.DetachUserPolicy(ctx, &iam.DetachUserPolicyInput{
			UserName:  aws.String(username),
			PolicyArn: p.PolicyArn,
		}); err != nil {
			continue
		}
	}

	// Delete all inline policies
	for _, p := range inlineResult.PolicyNames {
		if _, err := utils.IAMClient.DeleteUserPolicy(ctx, &iam.DeleteUserPolicyInput{
			UserName:   aws.String(username),
			PolicyName: aws.String(p),
		}); err != nil {
			continue
		}
	}

	// Delete access keys
	for _, k := range keysResult.AccessKeyMetadata {
		if _, err := utils.IAMClient.DeleteAccessKey(ctx, &iam.DeleteAccessKeyInput{
			UserName:    aws.String(username),
			AccessKeyId: k.AccessKeyId,
		}); err != nil {
			continue
		}
	}

	// Delete login profile if exists
	_, err = utils.IAMClient.GetLoginProfile(ctx, &iam.GetLoginProfileInput{
		UserName: aws.String(username),
	})
	if err == nil {
		// Ignore error on delete
		_, _ = utils.IAMClient.DeleteLoginProfile(ctx, &iam.DeleteLoginProfileInput{
			UserName: aws.String(username),
		})
	}

	// Delete the IAM user
	_, err = utils.IAMClient.DeleteUser(ctx, &iam.DeleteUserInput{
		UserName: aws.String(username),
	})

	return err
}
