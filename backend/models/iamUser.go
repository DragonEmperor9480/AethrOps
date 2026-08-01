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

