package ec2

// LaunchInstanceRequest defines the parameters for launching a new EC2 instance
type LaunchInstanceRequest struct {
	ImageID          string            `json:"image_id"`
	InstanceType     string            `json:"instance_type"`
	MinCount         int32             `json:"min_count"`
	MaxCount         int32             `json:"max_count"`
	KeyName          string            `json:"key_name,omitempty"`
	SecurityGroupIDs []string          `json:"security_group_ids,omitempty"`
	SubnetID         string            `json:"subnet_id,omitempty"`
	Tags             map[string]string `json:"tags,omitempty"`
	UserData         string            `json:"user_data,omitempty"`
	VolumeSize       int32             `json:"volume_size,omitempty"`
	VolumeType       string            `json:"volume_type,omitempty"`
}
