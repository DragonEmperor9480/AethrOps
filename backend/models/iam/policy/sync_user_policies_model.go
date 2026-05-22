package policy

import (
	"sync"
)

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

// SyncUserPolicies synchronizes user policies by attaching/detaching in parallel
func SyncUserPolicies(username string, desiredArns, currentArns []string) SyncPoliciesResult {
	result := SyncPoliciesResult{
		Username:     username,
		AttachedArns: []string{},
		DetachedArns: []string{},
		AttachErrors: []string{},
		DetachErrors: []string{},
		Success:      true,
	}

	// Convert to sets for efficient lookup
	currentSet := make(map[string]bool)
	for _, arn := range currentArns {
		currentSet[arn] = true
	}

	desiredSet := make(map[string]bool)
	for _, arn := range desiredArns {
		desiredSet[arn] = true
	}

	// Find policies to attach (in desired but not in current)
	toAttach := []string{}
	for _, arn := range desiredArns {
		if !currentSet[arn] {
			toAttach = append(toAttach, arn)
		}
	}

	// Find policies to detach (in current but not in desired)
	toDetach := []string{}
	for _, arn := range currentArns {
		if !desiredSet[arn] {
			toDetach = append(toDetach, arn)
		}
	}

	var wg sync.WaitGroup
	var mu sync.Mutex

	// Attach policies in parallel
	for _, arn := range toAttach {
		wg.Add(1)
		go func(policyArn string) {
			defer wg.Done()
			err := AttachUserPolicy(username, policyArn)
			mu.Lock()
			defer mu.Unlock()
			if err != nil {
				result.AttachErrors = append(result.AttachErrors, policyArn+": "+err.Error())
				result.Success = false
			} else {
				result.AttachedArns = append(result.AttachedArns, policyArn)
				result.AttachedCount++
			}
		}(arn)
	}

	// Detach policies in parallel
	for _, arn := range toDetach {
		wg.Add(1)
		go func(policyArn string) {
			defer wg.Done()
			err := DetachUserPolicy(username, policyArn)
			mu.Lock()
			defer mu.Unlock()
			if err != nil {
				result.DetachErrors = append(result.DetachErrors, policyArn+": "+err.Error())
				result.Success = false
			} else {
				result.DetachedArns = append(result.DetachedArns, policyArn)
				result.DetachedCount++
			}
		}(arn)
	}

	wg.Wait()
	return result
}
