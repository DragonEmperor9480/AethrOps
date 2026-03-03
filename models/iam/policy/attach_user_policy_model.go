package policy

import (
	"context"
	"sync"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/service/iam"
)

type AttachPolicyRequest struct {
	Username  string `json:"username"`
	PolicyArn string `json:"policy_arn"`
}

type AttachPolicyResult struct {
	Username  string `json:"username"`
	PolicyArn string `json:"policy_arn"`
	Success   bool   `json:"success"`
	Error     string `json:"error,omitempty"`
}

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
func AttachMultiplePolicies(requests []AttachPolicyRequest) []AttachPolicyResult {
	results := make([]AttachPolicyResult, len(requests))
	var wg sync.WaitGroup

	for i, req := range requests {
		wg.Add(1)
		go func(index int, request AttachPolicyRequest) {
			defer wg.Done()

			result := AttachPolicyResult{
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
