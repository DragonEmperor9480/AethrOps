package models

type CreateGroup struct {
	GroupName string `json:"groupname"`
}

type GroupDependencies struct {
	Users            []string `json:"users"`
	AttachedPolicies []string `json:"attached_policies"`
}

// UserInGroup represents a user in a group
type UserInGroup struct {
	UserName   string `json:"user_name"`
	UserID     string `json:"user_id"`
	CreateDate string `json:"create_date"`
}

