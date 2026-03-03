package policy

import (
	"github.com/DragonEmperor9480/AethrOps/models/iam/policy"
)

// AttachUserPolicyController attaches a single policy to a user
func AttachUserPolicyController(username, policyArn string) error {
	return policy.AttachUserPolicy(username, policyArn)
}

// AttachMultiplePoliciesController attaches multiple policies in parallel
func AttachMultiplePoliciesController(requests []policy.AttachPolicyRequest) []policy.AttachPolicyResult {
	return policy.AttachMultiplePolicies(requests)
}
