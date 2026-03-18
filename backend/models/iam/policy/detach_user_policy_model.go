package policy

import (
	"context"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/service/iam"
)

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
