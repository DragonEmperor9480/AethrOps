package models

type BatchCreateIAMUsersRequest struct {
	Users []UserCreationRequest `json:"users"`
}

// UserCreationRequest represents a single user creation request
type UserCreationRequest struct {
	Username     string `json:"username"`
	Password     string `json:"password"`
	RequireReset bool   `json:"require_reset"`
}

// UserCreationResult represents the result of creating a single user
type UserCreationResult struct {
	Username       string
	UserStatus     int
	PasswordStatus int
	Success        bool
	Error          string
}

type Username struct {
	Username string `json:"username"`
}

type ShareUserCredentials struct {
	Username   string `json:"username"`
	Password   string `json:"password"`
	Email      string `json:"email"`
	ConsoleURL string `json:"console_url"`
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

type UserDependencies struct {
	Groups          []string `json:"groups"`
	ManagedPolicies []string `json:"managed_policies"`
	InlinePolicies  []string `json:"inline_policies"`
	AccessKeys      []string `json:"access_keys"`
	HasLoginProfile bool     `json:"has_login_profile"`
}

// HasDependencies checks if user has any dependencies
func (d *UserDependencies) HasDependencies() bool {
	return len(d.Groups) > 0 || len(d.ManagedPolicies) > 0 ||
		len(d.InlinePolicies) > 0 || len(d.AccessKeys) > 0 ||
		d.HasLoginProfile
}

// AccessKeyInfo represents an access key
type AccessKeyInfo struct {
	AccessKeyID string `json:"access_key_id"`
	Status      string `json:"status"`
	CreateDate  string `json:"create_date"`
	UserName    string `json:"user_name"`
}
