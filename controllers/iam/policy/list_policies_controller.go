package policy

import (
	"github.com/DragonEmperor9480/AethrOps/models/iam/policy"
)

// ListPoliciesController lists all IAM policies
func ListPoliciesController(scope string) ([]policy.Policy, error) {
	return policy.ListPoliciesModel(scope)
}
