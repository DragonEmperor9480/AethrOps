package group

import (
	"context"
	"fmt"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/service/iam"
)

func AttachGroupPolicy(groupname, policyArn string) error {
	client := utils.GetIAMClient()
	ctx := context.TODO()

	input := &iam.AttachGroupPolicyInput{
		GroupName: &groupname,
		PolicyArn: &policyArn,
	}

	_, err := client.AttachGroupPolicy(ctx, input)
	if err != nil {
		return fmt.Errorf("failed to attach policy: %w", err)
	}

	return nil
}

func DetachGroupPolicy(groupname, policyArn string) error {
	client := utils.GetIAMClient()
	ctx := context.TODO()

	input := &iam.DetachGroupPolicyInput{
		GroupName: &groupname,
		PolicyArn: &policyArn,
	}

	_, err := client.DetachGroupPolicy(ctx, input)
	if err != nil {
		return fmt.Errorf("failed to detach policy: %w", err)
	}

	return nil
}

func ListGroupPolicies(groupname string) ([]map[string]string, error) {
	client := utils.GetIAMClient()
	ctx := context.TODO()

	input := &iam.ListAttachedGroupPoliciesInput{
		GroupName: &groupname,
	}

	result, err := client.ListAttachedGroupPolicies(ctx, input)
	if err != nil {
		return nil, fmt.Errorf("failed to list policies: %w", err)
	}

	policies := []map[string]string{}
	for _, policy := range result.AttachedPolicies {
		if policy.PolicyArn != nil && policy.PolicyName != nil {
			policies = append(policies, map[string]string{
				"policy_arn":  *policy.PolicyArn,
				"policy_name": *policy.PolicyName,
			})
		}
	}

	return policies, nil
}
