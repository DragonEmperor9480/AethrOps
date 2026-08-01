package controllers

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"

	"github.com/DragonEmperor9480/AethrOps/constants"
	"github.com/DragonEmperor9480/AethrOps/models"
	"github.com/DragonEmperor9480/AethrOps/service"
	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/iam"
	"github.com/aws/aws-sdk-go-v2/service/sts"
	"github.com/gorilla/mux"
)

// GetCallerIdentity returns the caller's identity information
func GetCallerIdentity(w http.ResponseWriter, r *http.Request) {
	ctx := context.TODO()
	stsClient := utils.GetSTSClient()

	result, err := stsClient.GetCallerIdentity(ctx, &sts.GetCallerIdentityInput{})
	if err != nil {
		utils.Error(w, http.StatusInternalServerError, constants.FailedToCreateIamUSer)
		return
	}

	// Extract username from ARN
	// ARN format: arn:aws:iam::123456789012:user/username or arn:aws:iam::123456789012:root
	arn := *result.Arn
	username := "Unknown"
	userType := "IAMUser"

	// Parse ARN to extract username
	if strings.Contains(arn, ":user/") {
		parts := strings.Split(arn, ":user/")
		if len(parts) == 2 {
			username = parts[1]
		}
	} else if strings.Contains(arn, ":root") {
		username = "Owner"
		userType = "Root"
	} else if strings.Contains(arn, ":assumed-role/") {
		parts := strings.Split(arn, ":assumed-role/")
		if len(parts) == 2 {
			roleParts := strings.Split(parts[1], "/")
			if len(roleParts) > 0 {
				username = roleParts[0]
			}
		}
		userType = "AssumedRole"
	}
	utils.Success(w, http.StatusOK, "Caller identity retrieved successfully", map[string]interface{}{
		"username":   username,
		"user_type":  userType,
		"account_id": *result.Account,
		"arn":        arn,
		"user_id":    *result.UserId,
	})
}

// ListIAMUsers returns all IAM users
func ListIAMUsers(w http.ResponseWriter, r *http.Request) {
	ctx := context.TODO()
	result, err := utils.IAMClient.ListUsers(ctx, &iam.ListUsersInput{})
	if err != nil {
		utils.Error(w, http.StatusInternalServerError, constants.FailedToListIamUser)
		return
	}

	users := make([]map[string]string, 0, len(result.Users))
	for _, u := range result.Users {
		users = append(users, map[string]string{
			"username":    aws.ToString(u.UserName),
			"user_id":     aws.ToString(u.UserId),
			"create_date": u.CreateDate.Format("2006-01-02T15:04:05Z"),
		})
	}

	utils.Success(w, http.StatusOK, constants.IamUsersFetchedSuccessfully, map[string]interface{}{"users": users})
}

// CreateMultipleIAMUsers creates multiple IAM users in parallel
func CreateMultipleIAMUsers(w http.ResponseWriter, r *http.Request) {
	var req models.BatchCreateIAMUsersRequest

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		utils.Error(w, http.StatusBadRequest, constants.FailedToDecodeRequestBody)
		return
	}

	if len(req.Users) == 0 {
		utils.Error(w, http.StatusBadRequest, constants.NoUsersFound)
		return
	}

	// Create users in parallel
	results := service.CreateMultipleIAMUsers(req.Users)

	successCount := 0
	for _, result := range results {
		if result.Success {
			successCount++
		}
	}

	utils.Success(w, http.StatusOK, constants.BatchUserCreationCompleted, map[string]interface{}{
		"total":         len(results),
		"success_count": successCount,
		"failure_count": len(results) - successCount,
		"results":       results,
	})
}

// CheckUserDependencies checks what dependencies a user has before deletion
func CheckUserDependencies(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	username := vars["username"]

	deps, err := service.CheckUserDependencies(username)
	if err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}

	respondJSON(w, http.StatusOK, deps)
}

// CheckMultipleUserDependencies checks dependencies for multiple users in parallel
func CheckMultipleUserDependencies(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Usernames []string `json:"usernames"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	if len(req.Usernames) == 0 {
		respondError(w, http.StatusBadRequest, "at least one username is required")
		return
	}

	// Check dependencies in parallel
	dependencies := service.CheckMultipleUserDependencies(req.Usernames)

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"dependencies": dependencies,
	})
}

// DeleteMultipleIAMUsers deletes multiple IAM users in parallel
func DeleteMultipleIAMUsers(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Users []struct {
			Username string `json:"username"`
			Force    bool   `json:"force"`
		} `json:"users"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	if len(req.Users) == 0 {
		respondError(w, http.StatusBadRequest, "at least one user is required")
		return
	}

	// Convert to model request format
	requests := make([]models.UserDeletionRequest, len(req.Users))
	for i, u := range req.Users {
		requests[i] = models.UserDeletionRequest{
			Username: u.Username,
			Force:    u.Force,
		}
	}

	// Delete users in parallel
	results := service.DeleteMultipleIAMUsers(requests)

	// Count successes and failures
	successCount := 0
	failureCount := 0
	for _, result := range results {
		if result.Success {
			successCount++
		} else {
			failureCount++
		}
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"message":       "Batch user deletion completed",
		"total":         len(results),
		"success_count": successCount,
		"failure_count": failureCount,
		"results":       results,
	})
}

// SetUserPassword sets initial password for a user
func SetUserPassword(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	username := vars["username"]

	var req struct {
		Password     string `json:"password"`
		RequireReset bool   `json:"require_reset"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	if req.Password == "" {
		respondError(w, http.StatusBadRequest, "password is required")
		return
	}

	status, err := service.SetInitialUserPasswordModel(username, req.Password, req.RequireReset)

	switch status {
	case constants.PasswordUserNotFound:
		respondError(w, http.StatusNotFound, "User '"+username+"' does not exist")
		return
	case constants.PasswordPolicyViolation:
		respondError(w, http.StatusBadRequest, "Password does not meet AWS policy requirements")
		return
	case constants.PasswordAlreadyExists:
		respondError(w, http.StatusConflict, "Password already exists for user '"+username+"'")
		return
	case constants.PasswordCreationError:
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	case constants.PasswordCreatedSuccess:
		respondJSON(w, http.StatusOK, map[string]interface{}{
			"message":       "Password set successfully",
			"username":      username,
			"require_reset": req.RequireReset,
		})
	}
}

// UpdateUserPassword updates user password
func UpdateUserPassword(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	username := vars["username"]

	var req struct {
		Password string `json:"password"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	err := service.UpdateUserPasswordModel(username, req.Password)
	if err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{"message": "Password updated", "username": username})
}

// ListAccessKeys lists access keys for user
func ListAccessKeys(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	username := vars["username"]

	keys, err := service.ListAccessKeysForUserModel(username)
	if err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"username":    username,
		"access_keys": keys,
	})
}

// ============ IAM GROUPS ============

// ListIAMGroups returns all IAM groups
func ListIAMGroups(w http.ResponseWriter, r *http.Request) {
	ctx := context.TODO()
	result, err := utils.IAMClient.ListGroups(ctx, &iam.ListGroupsInput{})
	if err != nil {
		utils.Error(w, http.StatusInternalServerError, "Failed to list IAM groups")
		return
	}

	groups := make([]map[string]string, 0, len(result.Groups))
	for _, g := range result.Groups {
		groups = append(groups, map[string]string{
			"groupname":   aws.ToString(g.GroupName),
			"group_id":    aws.ToString(g.GroupId),
			"create_date": g.CreateDate.Format("2006-01-02T15:04:05Z"),
		})
	}

	utils.Success(w, http.StatusOK, constants.IAMGroupsFetchedSuccessfully, map[string]interface{}{"groups": groups})
}

// CreateIAMGroup creates a new IAM group
func CreateIAMGroup(w http.ResponseWriter, r *http.Request) {
	var req models.CreateGroup

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		utils.Error(w, http.StatusBadRequest, constants.InvalidRequestBody)
		return
	}

	if req.GroupName == "" {
		utils.Error(w, http.StatusBadRequest, "groupname is required")
		return
	}

	status, err := service.CreateIAMGroup(req.GroupName)
	switch status {
	case constants.GroupAlreadyExists:
		utils.Error(w, http.StatusConflict, "Group '"+req.GroupName+"' already exists")
		return
	case constants.GroupCreationError:
		utils.Error(w, http.StatusInternalServerError, err.Error())
		return
	}

	utils.Success(w, http.StatusOK, constants.IAMGroupCreatedSuccessfully, nil)
}

// DeleteIAMGroup deletes an IAM group
func DeleteIAMGroup(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	groupname := vars["groupname"]

	// Check if force delete is requested
	force := r.URL.Query().Get("force") == "true"

	if force {
		err := service.ForceDeleteGroup(groupname)
		if err != nil {
			utils.Error(w, http.StatusInternalServerError, constants.FailedToDeleteGroup)
			return
		}
	} else {
		err := service.DeleteGroupModel(groupname)
		if err != nil {
			utils.Error(w, http.StatusInternalServerError, constants.FailedToDeleteGroup)
			return
		}
	}

	utils.Success(w, http.StatusOK, "Group deleted successfully", map[string]string{"groupname": groupname})
}

// CheckGroupDependencies checks if a group has dependencies
func CheckGroupDependencies(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	groupname := vars["groupname"]

	deps, err := service.CheckGroupDependencies(groupname)
	if err != nil {
		utils.Error(w, http.StatusInternalServerError, err.Error())
		return
	}

	utils.Success(w, http.StatusOK, "", deps)
}

// AddUserToGroup adds a user to a group
func AddUserToGroup(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	groupname := vars["groupname"]

	var req models.Username

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		utils.Error(w, http.StatusBadRequest, constants.InvalidRequestBody)
		return
	}

	err := service.AddUserToGroupModel(req.Username, groupname)
	if err != nil {
		utils.Error(w, http.StatusInternalServerError, constants.FailedToAddUserToGroup)
		return
	}

	utils.Success(w, http.StatusOK, "User added to group", map[string]string{"username": req.Username, "groupname": groupname})
}

// RemoveUserFromGroup removes a user from a group
func RemoveUserFromGroup(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	groupname := vars["groupname"]
	username := vars["username"]

	err := service.RemoveUserFromGroupModel(username, groupname)
	if err != nil {
		utils.Error(w, http.StatusInternalServerError, "Failed to remove user from group")
		return
	}

	utils.Success(w, http.StatusOK, "User removed from group", map[string]string{"username": username, "groupname": groupname})
}

// ListUsersInGroup lists all users in a group
func ListUsersInGroup(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	groupname := vars["groupname"]

	users, err := service.ListUsersInGroupModel(groupname)
	if err != nil {
		utils.Error(w, http.StatusInternalServerError, err.Error())
		return
	}

	utils.Success(w, http.StatusOK, "", map[string]interface{}{
		"groupname": groupname,
		"users":     users,
	})
}

// ListUserGroups lists all groups for a user
func ListUserGroups(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	username := vars["username"]

	groups := service.ListUserGroupsModel(username)
	utils.Success(w, http.StatusOK, "", map[string]interface{}{"username": username, "groups": groups})
}

// AttachGroupPolicy attaches a policy to a group
func AttachGroupPolicy(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	groupname := vars["groupname"]

	var req struct {
		PolicyArn string `json:"policy_arn"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	if req.PolicyArn == "" {
		respondError(w, http.StatusBadRequest, "policy_arn is required")
		return
	}

	err := service.AttachGroupPolicy(groupname, req.PolicyArn)
	if err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{"message": "Policy attached", "groupname": groupname, "policy_arn": req.PolicyArn})
}

// DetachGroupPolicy detaches a policy from a group
func DetachGroupPolicy(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	groupname := vars["groupname"]
	policyArn := vars["policy_arn"]

	err := service.DetachGroupPolicy(groupname, policyArn)
	if err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{"message": "Policy detached", "groupname": groupname, "policy_arn": policyArn})
}

// ListGroupPolicies lists all policies attached to a group
func ListGroupPolicies(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	groupname := vars["groupname"]

	policies, err := service.ListGroupPolicies(groupname)
	if err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{"groupname": groupname, "policies": policies})
}

// ListIAMPolicies lists all IAM policies
func ListIAMPolicies(w http.ResponseWriter, r *http.Request) {
	// Get scope from query parameter (All, AWS, or Local)
	scope := r.URL.Query().Get("scope")
	if scope == "" {
		scope = "All"
	}

	policies, err := service.ListPoliciesModel(scope)
	if err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"policies": policies,
		"count":    len(policies),
	})
}

// AttachUserPolicy attaches a single policy to a user
func AttachUserPolicy(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	username := vars["username"]

	var req struct {
		PolicyArn string `json:"policy_arn"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	if req.PolicyArn == "" {
		respondError(w, http.StatusBadRequest, "policy_arn is required")
		return
	}

	if err := service.AttachUserPolicy(username, req.PolicyArn); err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"message":    "Policy attached successfully",
		"username":   username,
		"policy_arn": req.PolicyArn,
	})
}

// AttachMultipleUserPolicies attaches multiple policies to users in parallel
func AttachMultipleUserPolicies(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Attachments []models.AttachPolicyRequest `json:"attachments"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		utils.Error(w, http.StatusBadRequest, constants.InvalidRequestBody)
		return
	}

	if len(req.Attachments) == 0 {
		utils.Error(w, http.StatusBadRequest, "at least one attachment is required")
		return
	}

	results := service.AttachMultiplePolicies(req.Attachments)

	successCount := 0
	for _, result := range results {
		if result.Success {
			successCount++
		}
	}
	failureCount := len(results) - successCount

	utils.Success(w, http.StatusOK, "", map[string]interface{}{
		"message":       "Batch policy attachment completed",
		"total":         len(results),
		"success_count": successCount,
		"failure_count": failureCount,
		"results":       results,
	})
}

// SyncUserPolicies synchronizes user policies (attach new, detach removed)
func SyncUserPolicies(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	username := vars["username"]

	var req struct {
		DesiredArns []string `json:"desired_arns"`
		CurrentArns []string `json:"current_arns"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, constants.InvalidRequestBody)
		return
	}

	result := service.SyncUserPolicies(username, req.DesiredArns, req.CurrentArns)

	respondJSON(w, http.StatusOK, result)
}

// SendUserCredentialsEmail sends IAM credentials to user via email
// TODO: TO USE DB HERE LATER
func SendUserCredentialsEmail(w http.ResponseWriter, r *http.Request) {
	var req models.ShareUserCredentials

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		utils.Error(w, http.StatusBadRequest, constants.InvalidRequestBody)
		return
	}

	if req.Username == "" || req.Password == "" || req.Email == "" {
		respondError(w, http.StatusBadRequest, "username, password, and email are required")
		return
	}

	// Load email config from file
	emailConfig, err := service.LoadEmailConfig()
	if err != nil {
		respondError(w, http.StatusBadRequest, "Email configuration not found. Please configure email settings first.")
		return
	}

	// Get the proper console sign-in URL
	consoleURL := req.ConsoleURL
	if consoleURL == "" {
		url, err := utils.GetConsoleSignInURL()
		if err != nil {
			// Fallback to generic console URL if we can't get account-specific URL
			consoleURL = "https://console.aws.amazon.com/"
		} else {
			consoleURL = url
		}
	}

	err = service.SendIAMCredentialsEmail(emailConfig, req.Username, req.Password, req.Email, consoleURL)
	if err != nil {
		utils.Error(w, http.StatusInternalServerError, err.Error())
		return
	}

	utils.Success(w, http.StatusOK, "Credentials sent successfully", map[string]interface{}{
		"message": "Credentials sent successfully",
		"email":   req.Email,
	})
}

// ============ HELPER FUNCTIONS ============

func respondJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(data)
}

func respondError(w http.ResponseWriter, status int, message string) {
	respondJSON(w, status, map[string]string{"error": message})
}
