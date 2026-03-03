package policy

import (
	"context"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/service/iam"
	"github.com/aws/aws-sdk-go-v2/service/iam/types"
)

type Policy struct {
	PolicyName   string `json:"policy_name"`
	PolicyArn    string `json:"policy_arn"`
	Path         string `json:"path"`
	CreateDate   string `json:"create_date"`
	IsAWSManaged bool   `json:"is_aws_managed"`
}

// ListPoliciesModel lists all IAM policies (both AWS managed and customer managed)
func ListPoliciesModel(scope string) ([]Policy, error) {
	client := utils.GetIAMClient()
	ctx := context.TODO()

	var policies []Policy
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
			policy := Policy{
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
