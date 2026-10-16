package service

import (
	"context"
	"sync"

	"github.com/DragonEmperor9480/AethrOps/models"
	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/service/iam"
	"github.com/aws/aws-sdk-go-v2/service/iam/types"
)

// AttachUserPolicy attaches a single policy to a user
func AttachUserPolicy(username, policyArn string) error {
	client := utils.GetIAMClient()
	ctx := context.TODO()

	input := &iam.AttachUserPolicyInput{
		UserName:  &username,
		PolicyArn: &policyArn,
	}

	_, err := client.AttachUserPolicy(ctx, input)
	return err
}

// AttachMultiplePolicies attaches multiple policies to users in parallel
func AttachMultiplePolicies(requests []models.AttachPolicyRequest) []models.AttachPolicyResult {
	results := make([]models.AttachPolicyResult, len(requests))
	var wg sync.WaitGroup

	for i, req := range requests {
		wg.Add(1)
		go func(index int, request models.AttachPolicyRequest) {
			defer wg.Done()

			result := models.AttachPolicyResult{
				Username:  request.Username,
				PolicyArn: request.PolicyArn,
				Success:   false,
			}

			err := AttachUserPolicy(request.Username, request.PolicyArn)
			if err != nil {
				result.Error = err.Error()
			} else {
				result.Success = true
			}

			results[index] = result
		}(i, req)
	}

	wg.Wait()
	return results
}

// SyncUserPolicies synchronizes user policies by attaching/detaching in parallel
func SyncUserPolicies(username string, desiredArns, currentArns []string) models.SyncPoliciesResult {
	result := models.SyncPoliciesResult{
		Username:     username,
		AttachedArns: []string{},
		DetachedArns: []string{},
		AttachErrors: []string{},
		DetachErrors: []string{},
		Success:      true,
	}

	// Convert to sets for efficient lookup
	currentSet := make(map[string]bool)
	for _, arn := range currentArns {
		currentSet[arn] = true
	}

	desiredSet := make(map[string]bool)
	for _, arn := range desiredArns {
		desiredSet[arn] = true
	}

	// Find policies to attach (in desired but not in current)
	toAttach := []string{}
	for _, arn := range desiredArns {
		if !currentSet[arn] {
			toAttach = append(toAttach, arn)
		}
	}

	// Find policies to detach (in current but not in desired)
	toDetach := []string{}
	for _, arn := range currentArns {
		if !desiredSet[arn] {
			toDetach = append(toDetach, arn)
		}
	}

	var wg sync.WaitGroup
	var mu sync.Mutex

	// Attach policies in parallel
	for _, arn := range toAttach {
		wg.Add(1)
		go func(policyArn string) {
			defer wg.Done()
			err := AttachUserPolicy(username, policyArn)
			mu.Lock()
			defer mu.Unlock()
			if err != nil {
				result.AttachErrors = append(result.AttachErrors, policyArn+": "+err.Error())
				result.Success = false
			} else {
				result.AttachedArns = append(result.AttachedArns, policyArn)
				result.AttachedCount++
			}
		}(arn)
	}

	// Detach policies in parallel
	for _, arn := range toDetach {
		wg.Add(1)
		go func(policyArn string) {
			defer wg.Done()
			err := DetachUserPolicy(username, policyArn)
			mu.Lock()
			defer mu.Unlock()
			if err != nil {
				result.DetachErrors = append(result.DetachErrors, policyArn+": "+err.Error())
				result.Success = false
			} else {
				result.DetachedArns = append(result.DetachedArns, policyArn)
				result.DetachedCount++
			}
		}(arn)
	}

	wg.Wait()
	return result
}

// DetachUserPolicy detaches a single policy from a user
func DetachUserPolicy(username, policyArn string) error {
	client := utils.GetIAMClient()
	ctx := context.TODO()

	input := &iam.DetachUserPolicyInput{
		UserName:  &username,
		PolicyArn: &policyArn,
	}

	_, err := client.DetachUserPolicy(ctx, input)
	return err
}

// ListPoliciesModel lists all IAM policies (both AWS managed and customer managed)
func ListPoliciesModel(scope string) ([]models.Policy, error) {
	client := utils.GetIAMClient()
	ctx := context.TODO()

	var policies []models.Policy
	var marker *string

	// Determine scope filter
	var scopeFilter types.PolicyScopeType
	switch scope {
	case "AWS":
		scopeFilter = types.PolicyScopeTypeAws
	case "Local":
		scopeFilter = types.PolicyScopeTypeLocal
	default:
		scopeFilter = types.PolicyScopeTypeAll
	}

	// Paginate through all policies
	for {
		input := &iam.ListPoliciesInput{
			Scope:  scopeFilter,
			Marker: marker,
		}

		result, err := client.ListPolicies(ctx, input)
		if err != nil {
			return nil, err
		}

		for _, p := range result.Policies {
			arn := *p.Arn
			policy := models.Policy{
				PolicyName:   *p.PolicyName,
				PolicyArn:    arn,
				Path:         *p.Path,
				IsAWSManaged: len(arn) >= 17 && arn[:17] == "arn:aws:iam::aws:",
			}

			if p.CreateDate != nil {
				policy.CreateDate = p.CreateDate.Format("2006-01-02 15:04:05")
			}

			policies = append(policies, policy)
		}

		if !result.IsTruncated {
			break
		}
		marker = result.Marker
	}

	return policies, nil
}

func AttachGroupPolicy(groupname, policyArn string) error {
	client := utils.GetIAMClient()
	ctx := context.TODO()

	input := &iam.AttachGroupPolicyInput{
		GroupName: &groupname,
		PolicyArn: &policyArn,
	}

	_, err := client.AttachGroupPolicy(ctx, input)
	if err != nil {
		return err
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
		return err
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
		return nil, err
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
