package user

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"strings"
	"sync"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/iam"
)

func DeleteIAMUser(username string) {
	ctx := context.TODO()
	reader := bufio.NewReader(os.Stdin)

	utils.ShowProcessingAnimation("Processing")

	// Check if user exists
	_, err := utils.IAMClient.GetUser(ctx, &iam.GetUserInput{
		UserName: aws.String(username),
	})

	utils.StopAnimation()

	if err != nil && strings.Contains(err.Error(), "NoSuchEntity") {
		fmt.Println(utils.Bold + utils.Red + "Error: User '" + username + "' does not exist!" + utils.Reset)
		return
	}

	utils.ShowProcessingAnimation("Checking IAM User dependencies...")

	// Get groups
	groupsResult, _ := utils.IAMClient.ListGroupsForUser(ctx, &iam.ListGroupsForUserInput{
		UserName: aws.String(username),
	})
	var groups []string
	for _, g := range groupsResult.Groups {
		groups = append(groups, aws.ToString(g.GroupName))
	}

	// Get attached managed policies
	policiesResult, _ := utils.IAMClient.ListAttachedUserPolicies(ctx, &iam.ListAttachedUserPoliciesInput{
		UserName: aws.String(username),
	})
	var policies []string
	var policyArns []string
	for _, p := range policiesResult.AttachedPolicies {
		policies = append(policies, aws.ToString(p.PolicyName))
		policyArns = append(policyArns, aws.ToString(p.PolicyArn))
	}

	// Get inline policies
	inlineResult, _ := utils.IAMClient.ListUserPolicies(ctx, &iam.ListUserPoliciesInput{
		UserName: aws.String(username),
	})
	inlinePolicies := inlineResult.PolicyNames

	// Get access keys
	keysResult, _ := utils.IAMClient.ListAccessKeys(ctx, &iam.ListAccessKeysInput{
		UserName: aws.String(username),
	})
	var accessKeys []string
	for _, k := range keysResult.AccessKeyMetadata {
		accessKeys = append(accessKeys, aws.ToString(k.AccessKeyId))
	}

	utils.StopAnimation()

	if len(groups) > 0 || len(policies) > 0 || len(inlinePolicies) > 0 || len(accessKeys) > 0 {
		fmt.Println(utils.Yellow + "User '" + username + "' has the following dependencies:" + utils.Reset)

		if len(groups) > 0 {
			fmt.Println(utils.Bold + "Groups:" + utils.Reset)
			for _, g := range groups {
				fmt.Println("  - " + g)
			}
		}
		if len(policies) > 0 {
			fmt.Println(utils.Bold + "Managed Policies:" + utils.Reset)
			for _, p := range policies {
				fmt.Println("  - " + p)
			}
		}
		if len(inlinePolicies) > 0 {
			fmt.Println(utils.Bold + "Inline Policies:" + utils.Reset)
			for _, p := range inlinePolicies {
				fmt.Println("  - " + p)
			}
		}
		if len(accessKeys) > 0 {
			fmt.Println(utils.Bold + "Access Keys:" + utils.Reset)
			for _, k := range accessKeys {
				fmt.Println("  - " + k)
			}
		}

		fmt.Print(utils.Red + "Do you want to remove all dependencies and delete the user? (y/N): " + utils.Reset)
		answer, _ := reader.ReadString('\n')
		answer = strings.ToLower(strings.TrimSpace(answer))

		if answer != "y" && answer != "yes" {
			fmt.Println(utils.Yellow + "Aborted user deletion." + utils.Reset)
			return
		}

		utils.ShowProcessingAnimation("Cleaning up IAM User dependencies")

		// Remove user from all groups
		for _, g := range groups {
			utils.IAMClient.RemoveUserFromGroup(ctx, &iam.RemoveUserFromGroupInput{
				UserName:  aws.String(username),
				GroupName: aws.String(g),
			})
		}

		// Detach all managed policies
		for _, arn := range policyArns {
			utils.IAMClient.DetachUserPolicy(ctx, &iam.DetachUserPolicyInput{
				UserName:  aws.String(username),
				PolicyArn: aws.String(arn),
			})
		}

		// Delete all inline policies
		for _, p := range inlinePolicies {
			utils.IAMClient.DeleteUserPolicy(ctx, &iam.DeleteUserPolicyInput{
				UserName:   aws.String(username),
				PolicyName: aws.String(p),
			})
		}

		// Delete access keys
		for _, k := range accessKeys {
			utils.IAMClient.DeleteAccessKey(ctx, &iam.DeleteAccessKeyInput{
				UserName:    aws.String(username),
				AccessKeyId: aws.String(k),
			})
		}
	}

	utils.StopAnimation()

	// Delete login profile if exists
	_, err = utils.IAMClient.GetLoginProfile(ctx, &iam.GetLoginProfileInput{
		UserName: aws.String(username),
	})
	if err == nil {
		fmt.Print("Would you like to delete the login profile for the user? (y/N): ")
		deleteLoginProfileChoice, _ := reader.ReadString('\n')
		deleteLoginProfileChoice = strings.ToLower(strings.TrimSpace(deleteLoginProfileChoice))
		if deleteLoginProfileChoice == "y" || deleteLoginProfileChoice == "yes" {
			utils.IAMClient.DeleteLoginProfile(ctx, &iam.DeleteLoginProfileInput{
				UserName: aws.String(username),
			})
		}
	}

	// Delete the IAM user
	utils.ShowProcessingAnimation("Deleting IAM User")
	_, err = utils.IAMClient.DeleteUser(ctx, &iam.DeleteUserInput{
		UserName: aws.String(username),
	})
	utils.StopAnimation()
	fmt.Println()

	if err != nil {
		if strings.Contains(err.Error(), "NoSuchEntity") {
			fmt.Println(utils.Bold + utils.Red + "Error: User '" + username + "' does not exist!" + utils.Reset)
		} else {
			fmt.Println(utils.Yellow + "Unexpected error occurred:" + utils.Reset)
			fmt.Println(err.Error())
		}
		return
	}

	fmt.Println(utils.Bold + utils.Green + "User '" + username + "' deleted successfully!" + utils.Reset)
}

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
						utils.IAMClient.RemoveUserFromGroup(ctx, &iam.RemoveUserFromGroupInput{
							UserName:  aws.String(request.Username),
							GroupName: aws.String(g),
						})
					}

					// Get policy ARNs and detach
					policiesResult, _ := utils.IAMClient.ListAttachedUserPolicies(ctx, &iam.ListAttachedUserPoliciesInput{
						UserName: aws.String(request.Username),
					})
					for _, p := range policiesResult.AttachedPolicies {
						utils.IAMClient.DetachUserPolicy(ctx, &iam.DetachUserPolicyInput{
							UserName:  aws.String(request.Username),
							PolicyArn: p.PolicyArn,
						})
					}

					// Delete inline policies
					for _, p := range deps.InlinePolicies {
						utils.IAMClient.DeleteUserPolicy(ctx, &iam.DeleteUserPolicyInput{
							UserName:   aws.String(request.Username),
							PolicyName: aws.String(p),
						})
					}

					// Delete access keys
					for _, k := range deps.AccessKeys {
						utils.IAMClient.DeleteAccessKey(ctx, &iam.DeleteAccessKeyInput{
							UserName:    aws.String(request.Username),
							AccessKeyId: aws.String(k),
						})
					}

					// Delete login profile
					if deps.HasLoginProfile {
						utils.IAMClient.DeleteLoginProfile(ctx, &iam.DeleteLoginProfileInput{
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
