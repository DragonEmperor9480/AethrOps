package user

import (
	"context"
	"strings"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/iam"
)

// Status codes for SetInitialUserPasswordModel
const (
	PasswordUserNotFound    = 1
	PasswordPolicyViolation = 2
	PasswordAlreadyExists   = 3
	PasswordCreationError   = 4
	PasswordCreatedSuccess  = 5
)

// SetInitialUserPasswordModel sets initial password for IAM user
// Returns status code and error
func SetInitialUserPasswordModel(username, password string, requireReset bool) (int, error) {
	ctx := context.TODO()

	_, err := utils.IAMClient.CreateLoginProfile(ctx, &iam.CreateLoginProfileInput{
		UserName:              aws.String(username),
		Password:              aws.String(password),
		PasswordResetRequired: requireReset,
	})

	if err != nil {
		if strings.Contains(err.Error(), "NoSuchEntity") {
			return PasswordUserNotFound, nil
		}
		if strings.Contains(err.Error(), "PasswordPolicyViolation") {
			return PasswordPolicyViolation, nil
		}
		if strings.Contains(err.Error(), "EntityAlreadyExists") {
			return PasswordAlreadyExists, nil
		}
		return PasswordCreationError, err
	}

	return PasswordCreatedSuccess, nil
}
