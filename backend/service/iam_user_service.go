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

// RemoveUserFromGroupModel removes a user from a group
func RemoveUserFromGroupModel(username, groupname string) error {
	client := utils.GetIAMClient()
	ctx := context.TODO()

	input := &iam.RemoveUserFromGroupInput{
		GroupName: &groupname,
		UserName:  &username,
	}

	_, err := client.RemoveUserFromGroup(ctx, input)
	if err != nil {
		return err
	}

	return nil
}

// UpdateUserPasswordModel updates a user's password
func UpdateUserPasswordModel(username, password string) error {
	ctx := context.TODO()
	_, err := utils.IAMClient.UpdateLoginProfile(ctx, &iam.UpdateLoginProfileInput{
		UserName: aws.String(username),
		Password: aws.String(password),
	})

	if err != nil {
		return err
	}

	return nil
}

// CheckMultipleUserDependencies checks dependencies for multiple users in parallel
func CheckMultipleUserDependencies(usernames []string) []models.UserDependenciesResult {
	results := make([]models.UserDependenciesResult, len(usernames))
	var wg sync.WaitGroup

	for i, username := range usernames {
		wg.Add(1)

		go func(index int, user string) {
			defer wg.Done()

			deps, err := CheckUserDependencies(user)

			result := models.UserDependenciesResult{
				Username:     user,
				Dependencies: deps,
			}

			if err != nil {
				if strings.Contains(err.Error(), "NoSuchEntity") {
					result.Error = "User does not exist"
				} else {
					result.Error = err.Error()
				}
			} else {
				// Get policy ARNs for managed policies
				ctx := context.TODO()
				policiesResult, _ := utils.IAMClient.ListAttachedUserPolicies(ctx, &iam.ListAttachedUserPoliciesInput{
					UserName: aws.String(user),
				})
				for _, p := range policiesResult.AttachedPolicies {
					result.PolicyArns = append(result.PolicyArns, aws.ToString(p.PolicyArn))
				}
			}

			results[index] = result
		}(i, username)
	}

	wg.Wait()
	return results
}

// DeleteMultipleIAMUsers deletes multiple users in parallel
func DeleteMultipleIAMUsers(requests []models.UserDeletionRequest) []models.UserDeletionResult {
	results := make([]models.UserDeletionResult, len(requests))
	var wg sync.WaitGroup

	for i, req := range requests {
		wg.Add(1)

		go func(index int, request models.UserDeletionRequest) {
			defer wg.Done()

			ctx := context.TODO()
			result := models.UserDeletionResult{
				Username: request.Username,
			}

			// If force is true, remove all dependencies first
			if request.Force {
				// Get dependencies
				deps, err := CheckUserDependencies(request.Username)
				if err == nil && deps != nil {
					// Remove from groups
					for _, g := range deps.Groups {
						_, _ = utils.IAMClient.RemoveUserFromGroup(ctx, &iam.RemoveUserFromGroupInput{
							UserName:  aws.String(request.Username),
							GroupName: aws.String(g),
						})
					}

					// Get policy ARNs and detach
					policiesResult, _ := utils.IAMClient.ListAttachedUserPolicies(ctx, &iam.ListAttachedUserPoliciesInput{
						UserName: aws.String(request.Username),
					})
					for _, p := range policiesResult.AttachedPolicies {
						_, _ = utils.IAMClient.DetachUserPolicy(ctx, &iam.DetachUserPolicyInput{
							UserName:  aws.String(request.Username),
							PolicyArn: p.PolicyArn,
						})
					}

					// Delete inline policies
					for _, p := range deps.InlinePolicies {
						_, _ = utils.IAMClient.DeleteUserPolicy(ctx, &iam.DeleteUserPolicyInput{
							UserName:   aws.String(request.Username),
							PolicyName: aws.String(p),
						})
					}

					// Delete access keys
					for _, k := range deps.AccessKeys {
						_, _ = utils.IAMClient.DeleteAccessKey(ctx, &iam.DeleteAccessKeyInput{
							UserName:    aws.String(request.Username),
							AccessKeyId: aws.String(k),
						})
					}

					// Delete login profile
					if deps.HasLoginProfile {
						_, _ = utils.IAMClient.DeleteLoginProfile(ctx, &iam.DeleteLoginProfileInput{
							UserName: aws.String(request.Username),
						})
					}
				}
			}

			// Delete the user
			_, err := utils.IAMClient.DeleteUser(ctx, &iam.DeleteUserInput{
				UserName: aws.String(request.Username),
			})

			if err != nil {
				result.Success = false
				if strings.Contains(err.Error(), "NoSuchEntity") {
					result.Error = "User does not exist"
				} else if strings.Contains(err.Error(), "DeleteConflict") {
					result.Error = "User has dependencies that must be removed first"
				} else {
					result.Error = err.Error()
				}
			} else {
				result.Success = true
			}

			results[index] = result
		}(i, req)
	}

	wg.Wait()
	return results
}

// CheckUserDependencies checks what dependencies a user has
func CheckUserDependencies(username string) (*models.UserDependencies, error) {
	ctx := context.TODO()
	deps := &models.UserDependencies{}

	// Check if user exists
	_, err := utils.IAMClient.GetUser(ctx, &iam.GetUserInput{
		UserName: aws.String(username),
	})
	if err != nil {
		return nil, err
	}

	// Get groups
	groupsResult, _ := utils.IAMClient.ListGroupsForUser(ctx, &iam.ListGroupsForUserInput{
		UserName: aws.String(username),
	})
	for _, g := range groupsResult.Groups {
		deps.Groups = append(deps.Groups, aws.ToString(g.GroupName))
	}

	// Get attached managed policies
	policiesResult, _ := utils.IAMClient.ListAttachedUserPolicies(ctx, &iam.ListAttachedUserPoliciesInput{
		UserName: aws.String(username),
	})
	for _, p := range policiesResult.AttachedPolicies {
		deps.ManagedPolicies = append(deps.ManagedPolicies, aws.ToString(p.PolicyName))
	}

	// Get inline policies
	inlineResult, _ := utils.IAMClient.ListUserPolicies(ctx, &iam.ListUserPoliciesInput{
		UserName: aws.String(username),
	})
	deps.InlinePolicies = append(deps.InlinePolicies, inlineResult.PolicyNames...)

	// Get access keys
	keysResult, _ := utils.IAMClient.ListAccessKeys(ctx, &iam.ListAccessKeysInput{
		UserName: aws.String(username),
	})
	for _, k := range keysResult.AccessKeyMetadata {
		deps.AccessKeys = append(deps.AccessKeys, aws.ToString(k.AccessKeyId))
	}

	// Check login profile
	_, err = utils.IAMClient.GetLoginProfile(ctx, &iam.GetLoginProfileInput{
		UserName: aws.String(username),
	})
	deps.HasLoginProfile = (err == nil)

	return deps, nil
}

// ListAccessKeysForUserModel lists access keys for a user
func ListAccessKeysForUserModel(username string) ([]models.AccessKeyInfo, error) {
	ctx := context.TODO()
	result, err := utils.IAMClient.ListAccessKeys(ctx, &iam.ListAccessKeysInput{
		UserName: aws.String(username),
	})

	if err != nil {
		return nil, err
	}

	keys := make([]models.AccessKeyInfo, 0, len(result.AccessKeyMetadata))
	for _, key := range result.AccessKeyMetadata {
		keys = append(keys, models.AccessKeyInfo{
			AccessKeyID: aws.ToString(key.AccessKeyId),
			Status:      string(key.Status),
			CreateDate:  key.CreateDate.String(),
			UserName:    aws.ToString(key.UserName),
		})
	}

	return keys, nil
}
