package user

import (
	"context"
	"strings"
	"sync"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/iam"
)

// UserDependenciesResult represents dependencies check result for a single user
type UserDependenciesResult struct {
	Username     string            `json:"username"`
	Dependencies *UserDependencies `json:"dependencies"`
	PolicyArns   []string          `json:"policy_arns"` // ARNs for managed policies
	Error        string            `json:"error"`
}

// UserDeletionRequest represents a request to delete a user
type UserDeletionRequest struct {
	Username string
	Force    bool // If true, remove all dependencies before deleting
}

// UserDeletionResult represents the result of deleting a user
type UserDeletionResult struct {
	Username string `json:"Username"`
	Success  bool   `json:"Success"`
	Error    string `json:"Error"`
}

// CheckMultipleUserDependencies checks dependencies for multiple users in parallel
func CheckMultipleUserDependencies(usernames []string) []UserDependenciesResult {
	results := make([]UserDependenciesResult, len(usernames))
	var wg sync.WaitGroup

	for i, username := range usernames {
		wg.Add(1)

		go func(index int, user string) {
			defer wg.Done()

			deps, err := CheckUserDependencies(user)

			result := UserDependenciesResult{
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
func DeleteMultipleIAMUsers(requests []UserDeletionRequest) []UserDeletionResult {
	results := make([]UserDeletionResult, len(requests))
	var wg sync.WaitGroup

	for i, req := range requests {
		wg.Add(1)

		go func(index int, request UserDeletionRequest) {
			defer wg.Done()

			ctx := context.TODO()
			result := UserDeletionResult{
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
