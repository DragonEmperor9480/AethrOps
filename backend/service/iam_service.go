package service

import (
	"context"
	"strings"
	"sync"

	"github.com/DragonEmperor9480/AethrOps/constants"
	"github.com/DragonEmperor9480/AethrOps/models"
	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/iam"
)

// CreateMultipleIAMUsers creates multiple IAM users in parallel using goroutines
func CreateMultipleIAMUsers(requests []models.UserCreationRequest) []models.UserCreationResult {
	results := make([]models.UserCreationResult, len(requests))

	// Use WaitGroup to wait for all goroutines to complete
	var wg sync.WaitGroup

	for i, req := range requests {
		wg.Add(1)

		// Launch goroutine for each user creation
		go func(index int, request models.UserCreationRequest) {
			defer wg.Done()

			result := models.UserCreationResult{
				Username: request.Username,
			}

			// If password is provided, create user with password
			if request.Password != "" {
				userStatus, passwordStatus, err := CreateIAMUserWithPassword(
					request.Username,
					request.Password,
					request.RequireReset,
				)

				result.UserStatus = userStatus
				result.PasswordStatus = passwordStatus

				if userStatus == constants.UserCreatedSuccess && passwordStatus == constants.PasswordCreatedSuccess {
					result.Success = true
				} else {
					result.Success = false
					if err != nil {
						result.Error = err.Error()
					} else {
						result.Error = getErrorMessage(userStatus, passwordStatus)
					}
				}
			} else {
				// Create user without password
				userStatus, err := CreateIAMUser(request.Username)

				result.UserStatus = userStatus
				result.PasswordStatus = 0

				if userStatus == constants.UserCreatedSuccess {
					result.Success = true
				} else {
					result.Success = false
					if err != nil {
						result.Error = err.Error()
					} else {
						result.Error = getUserErrorMessage(userStatus)
					}
				}
			}

			results[index] = result
		}(i, req)
	}

	// Wait for all goroutines to complete
	wg.Wait()

	return results
}

// Helper function to get error message from status codes
func getErrorMessage(userStatus, passwordStatus int) string {
	if userStatus != constants.UserCreatedSuccess {
		return getUserErrorMessage(userStatus)
	}
	return getPasswordErrorMessage(passwordStatus)
}

func getUserErrorMessage(status int) string {
	switch status {
	case constants.UserAlreadyExists:
		return "User already exists"
	case constants.UserCreationError:
		return "User creation error"
	default:
		return "Unknown error"
	}
}

func getPasswordErrorMessage(status int) string {
	switch status {
	case constants.PasswordUserNotFound:
		return "User not found"
	case constants.PasswordPolicyViolation:
		return "Password policy violation"
	case constants.PasswordAlreadyExists:
		return "Password already exists"
	case constants.PasswordCreationError:
		return "Password creation error"
	default:
		return "Unknown error"
	}
}

func CreateIAMUser(username string) (int, error) {
	// Execute AWS SDK call
	ctx := context.TODO()
	_, err := utils.IAMClient.CreateUser(ctx, &iam.CreateUserInput{
		UserName: aws.String(username),
	})

	if err != nil {
		if strings.Contains(err.Error(), "EntityAlreadyExists") {
			return constants.UserAlreadyExists, nil
		}
		return constants.UserCreationError, err
	}
	return constants.UserCreatedSuccess, nil
}

// CreateIAMUserWithPassword creates a user and sets initial password in one operation
// Returns user creation status code, password status code, and error
func CreateIAMUserWithPassword(username, password string, requireReset bool) (int, int, error) {
	// First create the user
	userStatus, err := CreateIAMUser(username)

	// If user creation failed, return immediately
	if userStatus != constants.UserCreatedSuccess {
		return userStatus, 0, err
	}

	// User created successfully, now set password
	passwordStatus, passwordErr := SetInitialUserPasswordModel(username, password, requireReset)

	return userStatus, passwordStatus, passwordErr
}

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
			return constants.PasswordUserNotFound, nil
		}
		if strings.Contains(err.Error(), "PasswordPolicyViolation") {
			return constants.PasswordPolicyViolation, nil
		}
		if strings.Contains(err.Error(), "EntityAlreadyExists") {
			return constants.PasswordAlreadyExists, nil
		}
		return constants.PasswordCreationError, err
	}

	return constants.PasswordCreatedSuccess, nil
}

// CreateIAMGroup creates a new IAM group
func CreateIAMGroup(groupname string) (int, error) {
	client := utils.GetIAMClient()
	ctx := context.TODO()

	_, err := client.CreateGroup(ctx, &iam.CreateGroupInput{
		GroupName: &groupname,
	})
	if err != nil {
		if strings.Contains(err.Error(), "EntityAlreadyExists") {
			return constants.GroupAlreadyExists, nil
		}
		return constants.GroupCreationError, err
	}

	return constants.GroupCreatedSuccess, nil
}
