package user

import (
	"context"
	"strings"
	"sync"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/iam"
)

// Status codes for CreateIAMUser
const (
	UserAlreadyExists  = 1
	UserCreationError  = 2
	UserCreatedSuccess = 3
)

func CreateIAMUser(username string) (int, error) {
	// Execute AWS SDK call
	ctx := context.TODO()
	_, err := utils.IAMClient.CreateUser(ctx, &iam.CreateUserInput{
		UserName: aws.String(username),
	})

	if err != nil {
		if strings.Contains(err.Error(), "EntityAlreadyExists") {
			return UserAlreadyExists, nil
		}
		return UserCreationError, err
	}
	return UserCreatedSuccess, nil
}

// CreateIAMUserWithPassword creates a user and sets initial password in one operation
// Returns user creation status code, password status code, and error
func CreateIAMUserWithPassword(username, password string, requireReset bool) (int, int, error) {
	// First create the user
	userStatus, err := CreateIAMUser(username)

	// If user creation failed, return immediately
	if userStatus != UserCreatedSuccess {
		return userStatus, 0, err
	}

	// User created successfully, now set password
	passwordStatus, passwordErr := SetInitialUserPasswordModel(username, password, requireReset)

	return userStatus, passwordStatus, passwordErr
}

// UserCreationRequest represents a single user creation request
type UserCreationRequest struct {
	Username     string
	Password     string
	RequireReset bool
}

// UserCreationResult represents the result of creating a single user
type UserCreationResult struct {
	Username       string
	UserStatus     int
	PasswordStatus int
	Success        bool
	Error          string
}

// CreateMultipleIAMUsers creates multiple IAM users in parallel using goroutines
func CreateMultipleIAMUsers(requests []UserCreationRequest) []UserCreationResult {
	results := make([]UserCreationResult, len(requests))

	// Use WaitGroup to wait for all goroutines to complete
	var wg sync.WaitGroup

	for i, req := range requests {
		wg.Add(1)

		// Launch goroutine for each user creation
		go func(index int, request UserCreationRequest) {
			defer wg.Done()

			result := UserCreationResult{
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

				if userStatus == UserCreatedSuccess && passwordStatus == PasswordCreatedSuccess {
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

				if userStatus == UserCreatedSuccess {
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
	if userStatus != UserCreatedSuccess {
		return getUserErrorMessage(userStatus)
	}
	return getPasswordErrorMessage(passwordStatus)
}

func getUserErrorMessage(status int) string {
	switch status {
	case UserAlreadyExists:
		return "User already exists"
	case UserCreationError:
		return "User creation error"
	default:
		return "Unknown error"
	}
}

func getPasswordErrorMessage(status int) string {
	switch status {
	case PasswordUserNotFound:
		return "User not found"
	case PasswordPolicyViolation:
		return "Password policy violation"
	case PasswordAlreadyExists:
		return "Password already exists"
	case PasswordCreationError:
		return "Password creation error"
	default:
		return "Unknown error"
	}
}
