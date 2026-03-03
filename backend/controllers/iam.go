package controllers

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"

	"github.com/DragonEmperor9480/aws_cli_manager/models/iam/group"
	"github.com/DragonEmperor9480/aws_cli_manager/models/iam/policy"
	"github.com/DragonEmperor9480/aws_cli_manager/models/iam/user"
	"github.com/DragonEmperor9480/aws_cli_manager/service"
	"github.com/DragonEmperor9480/aws_cli_manager/utils"
	"github.com/aws/aws-sdk-go-v2/service/sts"
	"github.com/gorilla/mux"
)

// GetCallerIdentity returns the caller's identity information
func GetCallerIdentity(w http.ResponseWriter, r *http.Request) {
	ctx := context.TODO()
	stsClient := utils.GetSTSClient()

	result, err := stsClient.GetCallerIdentity(ctx, &sts.GetCallerIdentityInput{})
	if err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
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

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"username":   username,
		"user_type":  userType,
		"account_id": *result.Account,
		"arn":        arn,
		"user_id":    *result.UserId,
	})
}

// ListIAMUsers returns all IAM users
func ListIAMUsers(w http.ResponseWriter, r *http.Request) {
	output, err := user.FetchIAMUsers()
	if err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}

	users := parseTabSeparated(output, []string{"username", "user_id", "create_date"})
	respondJSON(w, http.StatusOK, map[string]interface{}{"users": users})
}

// CreateMultipleIAMUsers creates multiple IAM users in parallel
func CreateMultipleIAMUsers(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Users []struct {
			Username     string `json:"username"`
			Password     string `json:"password"`
			RequireReset bool   `json:"require_reset"`
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
	requests := make([]user.UserCreationRequest, len(req.Users))
	for i, u := range req.Users {
		requests[i] = user.UserCreationRequest{
			Username:     u.Username,
			Password:     u.Password,
			RequireReset: u.RequireReset,
		}
	}

	// Create users in parallel
	results := user.CreateMultipleIAMUsers(requests)

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
		"message":       "Batch user creation completed",
		"total":         len(results),
		"success_count": successCount,
		"failure_count": failureCount,
		"results":       results,
	})
}

// CreateIAMUser creates a new IAM user with optional password
func CreateIAMUser(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Username     string `json:"username"`
		Password     string `json:"password"`      // Optional
		RequireReset bool   `json:"require_reset"` // Only used if password is provided
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	if req.Username == "" {
		respondError(w, http.StatusBadRequest, "username is required")
		return
	}

	// If password is provided, use combined function
	if req.Password != "" {
		userStatus, passwordStatus, err := user.CreateIAMUserWithPassword(req.Username, req.Password, req.RequireReset)

		// Check user creation status first
		switch userStatus {
		case user.UserAlreadyExists:
			respondError(w, http.StatusConflict, "User '"+req.Username+"' already exists")
			return
		case user.UserCreationError:
			respondError(w, http.StatusInternalServerError, err.Error())
			return
		}

		// User created, check password status
		switch passwordStatus {
		case user.PasswordUserNotFound:
			respondError(w, http.StatusNotFound, "User not found after creation")
			return
		case user.PasswordPolicyViolation:
			respondError(w, http.StatusBadRequest, "Password does not meet AWS policy requirements")
			return
		case user.PasswordAlreadyExists:
			respondError(w, http.StatusConflict, "Password already exists for user")
			return
		case user.PasswordCreationError:
			respondError(w, http.StatusInternalServerError, err.Error())
			return
		case user.PasswordCreatedSuccess:
			respondJSON(w, http.StatusOK, map[string]interface{}{
				"message":       "User created with password",
				"username":      req.Username,
				"password_set":  true,
				"require_reset": req.RequireReset,
			})
			return
		}
	}

	// No password provided, just create user
	status, err := user.CreateIAMUser(req.Username)

	switch status {
	case user.UserAlreadyExists:
		respondError(w, http.StatusConflict, "User '"+req.Username+"' already exists")
		return
	case user.UserCreationError:
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	case user.UserCreatedSuccess:
		respondJSON(w, http.StatusOK, map[string]interface{}{
			"message":      "User created",
			"username":     req.Username,
			"password_set": false,
		})
	}
}

// CheckUserDependencies checks what dependencies a user has before deletion
func CheckUserDependencies(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	username := vars["username"]

	deps, err := user.CheckUserDependencies(username)
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
	dependencies := user.CheckMultipleUserDependencies(req.Usernames)

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
	requests := make([]user.UserDeletionRequest, len(req.Users))
	for i, u := range req.Users {
		requests[i] = user.UserDeletionRequest{
			Username: u.Username,
			Force:    u.Force,
		}
	}

	// Delete users in parallel
	results := user.DeleteMultipleIAMUsers(requests)

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

// DeleteIAMUser deletes an IAM user (with force flag to remove dependencies)
func DeleteIAMUser(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	username := vars["username"]

	// Check for force parameter
	force := r.URL.Query().Get("force") == "true"

	if !force {
		// Check if user has dependencies
		deps, err := user.CheckUserDependencies(username)
		if err != nil {
			respondError(w, http.StatusInternalServerError, err.Error())
			return
		}

		if deps.HasDependencies() {
			respondError(w, http.StatusBadRequest, "User has dependencies. Use force=true to delete with dependencies.")
			return
		}
	}

	err := user.DeleteIAMUserAPI(username)
	if err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}
	respondJSON(w, http.StatusOK, map[string]string{"message": "User deleted", "username": username})
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

	status, err := user.SetInitialUserPasswordModel(username, req.Password, req.RequireReset)

	switch status {
	case user.PasswordUserNotFound:
		respondError(w, http.StatusNotFound, "User '"+username+"' does not exist")
		return
	case user.PasswordPolicyViolation:
		respondError(w, http.StatusBadRequest, "Password does not meet AWS policy requirements")
		return
	case user.PasswordAlreadyExists:
		respondError(w, http.StatusConflict, "Password already exists for user '"+username+"'")
		return
	case user.PasswordCreationError:
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	case user.PasswordCreatedSuccess:
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

	user.UpdateUserPasswordModel(username, req.Password)
	respondJSON(w, http.StatusOK, map[string]string{"message": "Password updated", "username": username})
}

// CreateAccessKey creates access key for user
func CreateAccessKey(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	username := vars["username"]

	user.CreateAccessKeyForUserModel(username)
	respondJSON(w, http.StatusOK, map[string]string{"message": "Access key created", "username": username})
}

// ListAccessKeys lists access keys for user
func ListAccessKeys(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	username := vars["username"]

	user.ListAccessKeysForUserModel(username)
	respondJSON(w, http.StatusOK, map[string]string{"message": "Access keys listed", "username": username})
}

// ============ IAM GROUPS ============

// ListIAMGroups returns all IAM groups
func ListIAMGroups(w http.ResponseWriter, r *http.Request) {
	output, err := group.FetchIAMGroups()
	if err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}

	groups := parseTabSeparated(output, []string{"groupname", "group_id", "create_date"})
	respondJSON(w, http.StatusOK, map[string]interface{}{"groups": groups})
}

// CreateIAMGroup creates a new IAM group
func CreateIAMGroup(w http.ResponseWriter, r *http.Request) {
	var req struct {
		GroupName string `json:"groupname"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	if req.GroupName == "" {
		respondError(w, http.StatusBadRequest, "groupname is required")
		return
	}

	group.CreateIAMGroup(req.GroupName)
	respondJSON(w, http.StatusOK, map[string]string{"message": "Group created", "groupname": req.GroupName})
}

// DeleteIAMGroup deletes an IAM group
func DeleteIAMGroup(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	groupname := vars["groupname"]

	// Check if force delete is requested
	force := r.URL.Query().Get("force") == "true"

	if force {
		err := group.ForceDeleteGroup(groupname)
		if err != nil {
			respondError(w, http.StatusInternalServerError, err.Error())
			return
		}
	} else {
		group.DeleteGroupModel(groupname)
	}

	respondJSON(w, http.StatusOK, map[string]string{"message": "Group deleted", "groupname": groupname})
}

// CheckGroupDependencies checks if a group has dependencies
func CheckGroupDependencies(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	groupname := vars["groupname"]

	deps, err := group.CheckGroupDependencies(groupname)
	if err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}

	respondJSON(w, http.StatusOK, deps)
}

// AddUserToGroup adds a user to a group
func AddUserToGroup(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	groupname := vars["groupname"]

	var req struct {
		Username string `json:"username"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	group.AddUserToGroupModel(req.Username, groupname)
	respondJSON(w, http.StatusOK, map[string]string{"message": "User added to group", "username": req.Username, "groupname": groupname})
}

// RemoveUserFromGroup removes a user from a group
func RemoveUserFromGroup(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	groupname := vars["groupname"]
	username := vars["username"]

	group.RemoveUserFromGroupModel(username, groupname)
	respondJSON(w, http.StatusOK, map[string]string{"message": "User removed from group", "username": username, "groupname": groupname})
}

// ListUsersInGroup lists all users in a group
func ListUsersInGroup(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	groupname := vars["groupname"]

	group.ListUsersInGroupModel(groupname)
	respondJSON(w, http.StatusOK, map[string]string{"message": "Users listed", "groupname": groupname})
}

// ListUserGroups lists all groups for a user
func ListUserGroups(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	username := vars["username"]

	groups := group.ListUserGroupsModel(username)
	respondJSON(w, http.StatusOK, map[string]interface{}{"username": username, "groups": groups})
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

	err := group.AttachGroupPolicy(groupname, req.PolicyArn)
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

	err := group.DetachGroupPolicy(groupname, policyArn)
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

	policies, err := group.ListGroupPolicies(groupname)
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

	policies, err := policy.ListPoliciesModel(scope)
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

	if err := policy.AttachUserPolicy(username, req.PolicyArn); err != nil {
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
		Attachments []policy.AttachPolicyRequest `json:"attachments"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	if len(req.Attachments) == 0 {
		respondError(w, http.StatusBadRequest, "at least one attachment is required")
		return
	}

	results := policy.AttachMultiplePolicies(req.Attachments)

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
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	result := policy.SyncUserPolicies(username, req.DesiredArns, req.CurrentArns)

	respondJSON(w, http.StatusOK, result)
}

// SendUserCredentialsEmail sends IAM credentials to user via email
func SendUserCredentialsEmail(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Username   string `json:"username"`
		Password   string `json:"password"`
		Email      string `json:"email"`
		ConsoleURL string `json:"console_url"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
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
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"message": "Credentials sent successfully",
		"email":   req.Email,
	})
}

// ============ HELPER FUNCTIONS ============

func parseTabSeparated(output string, fields []string) []map[string]string {
	result := []map[string]string{}
	lines := strings.Split(strings.TrimSpace(output), "\n")

	for _, line := range lines {
		if line == "" {
			continue
		}
		parts := strings.Split(line, "\t")
		if len(parts) >= len(fields) {
			item := make(map[string]string)
			for i, field := range fields {
				item[field] = parts[i]
			}
			result = append(result, item)
		}
	}

	return result
}

func respondJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

func respondError(w http.ResponseWriter, status int, message string) {
	respondJSON(w, status, map[string]string{"error": message})
}
