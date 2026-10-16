package models

type AttachPolicyRequest struct {
	Username  string `json:"username"`
	PolicyArn string `json:"policy_arn"`
}

type AttachPolicyResult struct {
	Username  string `json:"username"`
	PolicyArn string `json:"policy_arn"`
	Success   bool   `json:"success"`
	Error     string `json:"error,omitempty"`
}

type SyncPoliciesRequest struct {
	Username    string   `json:"username"`
	DesiredArns []string `json:"desired_arns"` // ARNs that should be attached
	CurrentArns []string `json:"current_arns"` // ARNs currently attached
}

type SyncPoliciesResult struct {
	Username      string   `json:"username"`
	AttachedCount int      `json:"attached_count"`
	DetachedCount int      `json:"detached_count"`
	AttachedArns  []string `json:"attached_arns"`
	DetachedArns  []string `json:"detached_arns"`
	AttachErrors  []string `json:"attach_errors,omitempty"`
	DetachErrors  []string `json:"detach_errors,omitempty"`
	Success       bool     `json:"success"`
}


type Policy struct {
	PolicyName   string `json:"policy_name"`
	PolicyArn    string `json:"policy_arn"`
	Path         string `json:"path"`
	CreateDate   string `json:"create_date"`
	IsAWSManaged bool   `json:"is_aws_managed"`
}