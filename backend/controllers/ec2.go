package controllers

import (
	"context"
	"encoding/base64"
	"net/http"
	"time"

	ec2models "github.com/DragonEmperor9480/AethrOps/models/ec2"
	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	"github.com/aws/aws-sdk-go-v2/service/ec2/types"
	"github.com/gin-gonic/gin"
	"github.com/gorilla/mux"
)

// ListEC2Instances returns all EC2 instances
func ListEC2Instances(w http.ResponseWriter, r *http.Request) {
	// Check for optional region parameter
	region := r.URL.Query().Get("region")

	var client *ec2.Client
	var err error

	if region != "" {
		// Use region-specific client
		client, err = utils.GetEC2ClientForRegion(region)
		if err != nil {
			respondError(w, http.StatusBadRequest, "Invalid region: "+err.Error())
			return
		}
	} else {
		// Use default client (current region)
		client = utils.GetEC2Client()
		region = utils.GetCurrentRegion()
	}

	ctx := context.TODO()

	var instances []map[string]interface{}
	var nextToken *string

	for {
		input := &ec2.DescribeInstancesInput{
			MaxResults: aws.Int32(100),
		}
		if nextToken != nil {
			input.NextToken = nextToken
		}

		result, err := client.DescribeInstances(ctx, input)
		if err != nil {
			respondError(w, http.StatusInternalServerError, "Failed to list EC2 instances: "+err.Error())
			return
		}

		// Parse reservations and instances
		for _, reservation := range result.Reservations {
			for _, instance := range reservation.Instances {
				// Get instance name from tags
				instanceName := ""
				for _, tag := range instance.Tags {
					if aws.ToString(tag.Key) == "Name" {
						instanceName = aws.ToString(tag.Value)
						break
					}
				}

				instanceData := map[string]interface{}{
					"instance_id":   aws.ToString(instance.InstanceId),
					"name":          instanceName,
					"state":         string(instance.State.Name),
					"platform":      aws.ToString(instance.PlatformDetails),
					"architecture":  string(instance.Architecture),
					"instance_type": string(instance.InstanceType),
					"region":        region,
				}

				instances = append(instances, instanceData)
			}
		}

		if result.NextToken == nil {
			break
		}
		nextToken = result.NextToken
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"instances": instances,
		"count":     len(instances),
		"region":    region,
	})
}

// GetEC2Instance retrieves details of a specific EC2 instance
func GetEC2Instance(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	instanceID := vars["instance_id"]
	if instanceID == "" {
		respondError(w, http.StatusBadRequest, "instance_id is required")
		return
	}

	// Check for optional region parameter
	region := r.URL.Query().Get("region")

	var client *ec2.Client
	var err error

	if region != "" {
		// Use region-specific client
		client, err = utils.GetEC2ClientForRegion(region)
		if err != nil {
			respondError(w, http.StatusBadRequest, "Invalid region: "+err.Error())
			return
		}
	} else {
		// Use default client (current region)
		client = utils.GetEC2Client()
	}

	ctx := context.TODO()

	input := &ec2.DescribeInstancesInput{
		InstanceIds: []string{instanceID},
	}

	result, err := client.DescribeInstances(ctx, input)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to get EC2 instance: "+err.Error())
		return
	}

	if len(result.Reservations) == 0 || len(result.Reservations[0].Instances) == 0 {
		respondError(w, http.StatusNotFound, "Instance not found")
		return
	}

	instance := result.Reservations[0].Instances[0]

	// Get instance name from tags
	tags := make(map[string]string)
	instanceName := ""
	for _, tag := range instance.Tags {
		tagKey := aws.ToString(tag.Key)
		tagValue := aws.ToString(tag.Value)
		tags[tagKey] = tagValue
		if tagKey == "Name" {
			instanceName = tagValue
		}
	}

	// Build detailed response
	instanceData := map[string]interface{}{
		"instance_id":         aws.ToString(instance.InstanceId),
		"name":                instanceName,
		"instance_type":       string(instance.InstanceType),
		"state":               string(instance.State.Name),
		"state_code":          instance.State.Code,
		"launch_time":         aws.ToTime(instance.LaunchTime).Format("2006-01-02 15:04:05"),
		"availability_zone":   aws.ToString(instance.Placement.AvailabilityZone),
		"private_ip":          aws.ToString(instance.PrivateIpAddress),
		"public_ip":           aws.ToString(instance.PublicIpAddress),
		"vpc_id":              aws.ToString(instance.VpcId),
		"subnet_id":           aws.ToString(instance.SubnetId),
		"image_id":            aws.ToString(instance.ImageId),
		"key_name":            aws.ToString(instance.KeyName),
		"monitoring_state":    string(instance.Monitoring.State),
		"architecture":        string(instance.Architecture),
		"platform":            aws.ToString(instance.PlatformDetails),
		"root_device_type":    string(instance.RootDeviceType),
		"root_device_name":    aws.ToString(instance.RootDeviceName),
		"virtualization_type": string(instance.VirtualizationType),
		"instance_lifecycle":  string(instance.InstanceLifecycle),
		"tags":                tags,
	}

	// IAM instance profile (check for nil)
	if instance.IamInstanceProfile != nil {
		instanceData["iam_instance_profile"] = aws.ToString(instance.IamInstanceProfile.Arn)
	}

	// Security groups
	securityGroups := make([]map[string]string, 0)
	for _, sg := range instance.SecurityGroups {
		securityGroups = append(securityGroups, map[string]string{
			"group_id":   aws.ToString(sg.GroupId),
			"group_name": aws.ToString(sg.GroupName),
		})
	}
	instanceData["security_groups"] = securityGroups

	// Network interfaces
	networkInterfaces := make([]map[string]interface{}, 0)
	for _, ni := range instance.NetworkInterfaces {
		niData := map[string]interface{}{
			"network_interface_id": aws.ToString(ni.NetworkInterfaceId),
			"private_ip":           aws.ToString(ni.PrivateIpAddress),
			"subnet_id":            aws.ToString(ni.SubnetId),
			"vpc_id":               aws.ToString(ni.VpcId),
			"mac_address":          aws.ToString(ni.MacAddress),
		}
		// Association might be nil if no public IP
		if ni.Association != nil {
			niData["public_ip"] = aws.ToString(ni.Association.PublicIp)
		}
		networkInterfaces = append(networkInterfaces, niData)
	}
	instanceData["network_interfaces"] = networkInterfaces

	// Block devices
	blockDevices := make([]map[string]interface{}, 0)
	for _, bdm := range instance.BlockDeviceMappings {
		if bdm.Ebs != nil {
			blockDevices = append(blockDevices, map[string]interface{}{
				"device_name":           aws.ToString(bdm.DeviceName),
				"volume_id":             aws.ToString(bdm.Ebs.VolumeId),
				"status":                string(bdm.Ebs.Status),
				"delete_on_termination": aws.ToBool(bdm.Ebs.DeleteOnTermination),
				"attach_time":           aws.ToTime(bdm.Ebs.AttachTime).Format("2006-01-02 15:04:05"),
			})
		}
	}
	instanceData["block_devices"] = blockDevices

	respondJSON(w, http.StatusOK, instanceData)
}

// StartEC2Instance starts a stopped EC2 instance
func StartEC2Instance(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	instanceID := vars["instance_id"]
	if instanceID == "" {
		respondError(w, http.StatusBadRequest, "instance_id is required")
		return
	}

	// Check for optional region parameter
	region := r.URL.Query().Get("region")

	var client *ec2.Client
	var err error

	if region != "" {
		client, err = utils.GetEC2ClientForRegion(region)
		if err != nil {
			respondError(w, http.StatusBadRequest, "Invalid region: "+err.Error())
			return
		}
	} else {
		client = utils.GetEC2Client()
	}

	ctx := context.TODO()

	input := &ec2.StartInstancesInput{
		InstanceIds: []string{instanceID},
	}

	result, err := client.StartInstances(ctx, input)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to start EC2 instance: "+err.Error())
		return
	}

	if len(result.StartingInstances) > 0 {
		instance := result.StartingInstances[0]
		respondJSON(w, http.StatusOK, map[string]interface{}{
			"message":        "Instance starting",
			"instance_id":    aws.ToString(instance.InstanceId),
			"previous_state": string(instance.PreviousState.Name),
			"current_state":  string(instance.CurrentState.Name),
		})
	} else {
		respondError(w, http.StatusInternalServerError, "Failed to start instance")
	}
}

// StopEC2Instance stops a running EC2 instance
func StopEC2Instance(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	instanceID := vars["instance_id"]
	if instanceID == "" {
		respondError(w, http.StatusBadRequest, "instance_id is required")
		return
	}

	// Check for optional region parameter
	region := r.URL.Query().Get("region")

	var client *ec2.Client
	var err error

	if region != "" {
		client, err = utils.GetEC2ClientForRegion(region)
		if err != nil {
			respondError(w, http.StatusBadRequest, "Invalid region: "+err.Error())
			return
		}
	} else {
		client = utils.GetEC2Client()
	}

	ctx := context.TODO()

	input := &ec2.StopInstancesInput{
		InstanceIds: []string{instanceID},
	}

	result, err := client.StopInstances(ctx, input)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to stop EC2 instance: "+err.Error())
		return
	}

	if len(result.StoppingInstances) > 0 {
		instance := result.StoppingInstances[0]
		respondJSON(w, http.StatusOK, map[string]interface{}{
			"message":        "Instance stopping",
			"instance_id":    aws.ToString(instance.InstanceId),
			"previous_state": string(instance.PreviousState.Name),
			"current_state":  string(instance.CurrentState.Name),
		})
	} else {
		respondError(w, http.StatusInternalServerError, "Failed to stop instance")
	}
}

// RebootEC2Instance reboots an EC2 instance
func RebootEC2Instance(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	instanceID := vars["instance_id"]
	if instanceID == "" {
		respondError(w, http.StatusBadRequest, "instance_id is required")
		return
	}

	// Check for optional region parameter
	region := r.URL.Query().Get("region")

	var client *ec2.Client
	var err error

	if region != "" {
		client, err = utils.GetEC2ClientForRegion(region)
		if err != nil {
			respondError(w, http.StatusBadRequest, "Invalid region: "+err.Error())
			return
		}
	} else {
		client = utils.GetEC2Client()
	}

	ctx := context.TODO()

	input := &ec2.RebootInstancesInput{
		InstanceIds: []string{instanceID},
	}

	_, err = client.RebootInstances(ctx, input)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to reboot EC2 instance: "+err.Error())
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{
		"message":     "Instance rebooting",
		"instance_id": instanceID,
	})
}

// TerminateEC2Instance terminates an EC2 instance
func TerminateEC2Instance(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	instanceID := vars["instance_id"]
	if instanceID == "" {
		respondError(w, http.StatusBadRequest, "instance_id is required")
		return
	}

	// Check for optional region parameter
	region := r.URL.Query().Get("region")

	var client *ec2.Client
	var err error

	if region != "" {
		client, err = utils.GetEC2ClientForRegion(region)
		if err != nil {
			respondError(w, http.StatusBadRequest, "Invalid region: "+err.Error())
			return
		}
	} else {
		client = utils.GetEC2Client()
	}

	ctx := context.TODO()

	input := &ec2.TerminateInstancesInput{
		InstanceIds: []string{instanceID},
	}

	result, err := client.TerminateInstances(ctx, input)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to terminate EC2 instance: "+err.Error())
		return
	}

	if len(result.TerminatingInstances) > 0 {
		instance := result.TerminatingInstances[0]
		respondJSON(w, http.StatusOK, map[string]interface{}{
			"message":        "Instance terminating",
			"instance_id":    aws.ToString(instance.InstanceId),
			"previous_state": string(instance.PreviousState.Name),
			"current_state":  string(instance.CurrentState.Name),
		})
	} else {
		respondError(w, http.StatusInternalServerError, "Failed to terminate instance")
	}
}

// GetInstanceStateChanges filters instances by state
func GetInstanceStateChanges(w http.ResponseWriter, r *http.Request) {
	state := r.URL.Query().Get("state")
	if state == "" {
		respondError(w, http.StatusBadRequest, "state parameter is required (running, stopped, pending, stopping, terminated)")
		return
	}

	// Validate state
	var instanceState types.InstanceStateName
	switch state {
	case "running":
		instanceState = types.InstanceStateNameRunning
	case "stopped":
		instanceState = types.InstanceStateNameStopped
	case "pending":
		instanceState = types.InstanceStateNamePending
	case "stopping":
		instanceState = types.InstanceStateNameStopping
	case "terminated":
		instanceState = types.InstanceStateNameTerminated
	case "shutting-down":
		instanceState = types.InstanceStateNameShuttingDown
	default:
		respondError(w, http.StatusBadRequest, "Invalid state. Valid states: running, stopped, pending, stopping, shutting-down, terminated")
		return
	}

	client := utils.GetEC2Client()
	ctx := context.TODO()

	input := &ec2.DescribeInstancesInput{
		Filters: []types.Filter{
			{
				Name:   aws.String("instance-state-name"),
				Values: []string{string(instanceState)},
			},
		},
	}

	result, err := client.DescribeInstances(ctx, input)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to get instances: "+err.Error())
		return
	}

	var instances []map[string]interface{}
	for _, reservation := range result.Reservations {
		for _, instance := range reservation.Instances {
			instanceName := ""
			for _, tag := range instance.Tags {
				if aws.ToString(tag.Key) == "Name" {
					instanceName = aws.ToString(tag.Value)
					break
				}
			}

			instances = append(instances, map[string]interface{}{
				"instance_id":   aws.ToString(instance.InstanceId),
				"name":          instanceName,
				"instance_type": string(instance.InstanceType),
				"state":         string(instance.State.Name),
				"launch_time":   aws.ToTime(instance.LaunchTime).Format("2006-01-02 15:04:05"),
				"public_ip":     aws.ToString(instance.PublicIpAddress),
				"private_ip":    aws.ToString(instance.PrivateIpAddress),
			})
		}
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"instances": instances,
		"count":     len(instances),
		"state":     state,
	})
}

// LaunchEC2Instance launches a new EC2 instance
func LaunchEC2Instance(c *gin.Context) {
	var req ec2models.LaunchInstanceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Validation
	if req.ImageID == "" || req.InstanceType == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "image_id and instance_type are required"})
		return
	}

	if req.MinCount < 1 {
		req.MinCount = 1
	}
	if req.MaxCount < 1 {
		req.MaxCount = 1
	}

	// Get EC2 client for specified region or default
	var client *ec2.Client
	var region string
	if req.Region != "" {
		var err error
		client, err = utils.GetEC2ClientForRegion(req.Region)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid region: " + err.Error()})
			return
		}
		region = req.Region
	} else {
		client = utils.GetEC2Client()
		region = utils.GetCurrentRegion()
	}

	ctx := context.TODO()

	// If storage size is requested, we need the RootDeviceName from the image
	var rootDeviceName string
	if req.VolumeSize > 0 {
		imageOutput, err := client.DescribeImages(ctx, &ec2.DescribeImagesInput{
			ImageIds: []string{req.ImageID},
		})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to describe image: " + err.Error()})
			return
		}
		if len(imageOutput.Images) == 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Image not found"})
			return
		}
		rootDeviceName = aws.ToString(imageOutput.Images[0].RootDeviceName)
	}

	input := &ec2.RunInstancesInput{
		ImageId:      aws.String(req.ImageID),
		InstanceType: types.InstanceType(req.InstanceType),
		MinCount:     aws.Int32(req.MinCount),
		MaxCount:     aws.Int32(req.MaxCount),
	}

	if req.KeyName != "" {
		input.KeyName = aws.String(req.KeyName)
	}

	if req.SubnetID != "" {
		input.SubnetId = aws.String(req.SubnetID)
	}

	if len(req.SecurityGroupIDs) > 0 {
		input.SecurityGroupIds = req.SecurityGroupIDs
	}

	// Handle UserData (Base64 encode)
	if req.UserData != "" {
		encoded := base64.StdEncoding.EncodeToString([]byte(req.UserData))
		input.UserData = aws.String(encoded)
	}

	// Handle Tags using TagSpecifications (atomic tagging)
	if len(req.Tags) > 0 {
		var awsTags []types.Tag
		for k, v := range req.Tags {
			awsTags = append(awsTags, types.Tag{
				Key:   aws.String(k),
				Value: aws.String(v),
			})
		}

		input.TagSpecifications = []types.TagSpecification{
			{
				ResourceType: types.ResourceTypeInstance,
				Tags:         awsTags,
			},
			{
				ResourceType: types.ResourceTypeVolume, // Also tag volumes
				Tags:         awsTags,
			},
		}
	}

	// Handle Storage Size (Root Volume)
	if req.VolumeSize > 0 && rootDeviceName != "" {
		volumeType := types.VolumeTypeGp3
		if req.VolumeType != "" {
			volumeType = types.VolumeType(req.VolumeType)
		}

		input.BlockDeviceMappings = []types.BlockDeviceMapping{
			{
				DeviceName: aws.String(rootDeviceName),
				Ebs: &types.EbsBlockDevice{
					VolumeSize: aws.Int32(req.VolumeSize),
					VolumeType: volumeType,
				},
			},
		}
	}

	result, err := client.RunInstances(ctx, input)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to launch instance: " + err.Error()})
		return
	}

	if len(result.Instances) == 0 {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "No instances returned from launch request"})
		return
	}

	// Return details of the first launched instance
	instance := result.Instances[0]
	c.JSON(http.StatusOK, gin.H{
		"message":        "Instance launched successfully",
		"instance_id":    aws.ToString(instance.InstanceId),
		"launch_time":    aws.ToTime(instance.LaunchTime).Format("2006-01-02 15:04:05"),
		"private_ip":     aws.ToString(instance.PrivateIpAddress),
		"state":          string(instance.State.Name),
		"instance_count": len(result.Instances),
		"region":         region,
	})
}

// ListSecurityGroups returns all security groups
func ListSecurityGroups(c *gin.Context) {
	client := utils.GetEC2Client()
	ctx := context.TODO()

	input := &ec2.DescribeSecurityGroupsInput{}
	result, err := client.DescribeSecurityGroups(ctx, input)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to list security groups: " + err.Error()})
		return
	}

	var groups []map[string]string
	for _, sg := range result.SecurityGroups {
		groups = append(groups, map[string]string{
			"group_id":    aws.ToString(sg.GroupId),
			"group_name":  aws.ToString(sg.GroupName),
			"description": aws.ToString(sg.Description),
			"vpc_id":      aws.ToString(sg.VpcId),
		})
	}

	c.JSON(http.StatusOK, gin.H{
		"security_groups": groups,
		"count":           len(groups),
	})
}

// ListKeyPairs returns all key pairs
func ListKeyPairs(c *gin.Context) {
	client := utils.GetEC2Client()
	ctx := context.TODO()

	input := &ec2.DescribeKeyPairsInput{}
	result, err := client.DescribeKeyPairs(ctx, input)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to list key pairs: " + err.Error()})
		return
	}

	var keyPairs []map[string]string
	for _, kp := range result.KeyPairs {
		keyPairs = append(keyPairs, map[string]string{
			"key_name":        aws.ToString(kp.KeyName),
			"key_pair_id":     aws.ToString(kp.KeyPairId),
			"key_fingerprint": aws.ToString(kp.KeyFingerprint),
		})
	}

	c.JSON(http.StatusOK, gin.H{
		"key_pairs": keyPairs,
		"count":     len(keyPairs),
	})
}

// ListSubnets returns all subnets
func ListSubnets(c *gin.Context) {
	client := utils.GetEC2Client()
	ctx := context.TODO()

	input := &ec2.DescribeSubnetsInput{}
	result, err := client.DescribeSubnets(ctx, input)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to list subnets: " + err.Error()})
		return
	}

	var subnets []map[string]string
	for _, sn := range result.Subnets {
		name := ""
		for _, tag := range sn.Tags {
			if aws.ToString(tag.Key) == "Name" {
				name = aws.ToString(tag.Value)
				break
			}
		}

		subnets = append(subnets, map[string]string{
			"subnet_id":         aws.ToString(sn.SubnetId),
			"vpc_id":            aws.ToString(sn.VpcId),
			"cidr_block":        aws.ToString(sn.CidrBlock),
			"availability_zone": aws.ToString(sn.AvailabilityZone),
			"name":              name,
		})
	}

	c.JSON(http.StatusOK, gin.H{
		"subnets": subnets,
		"count":   len(subnets),
	})
}

// ListVPCs returns all VPCs
func ListVPCs(c *gin.Context) {
	client := utils.GetEC2Client()
	ctx := context.TODO()

	input := &ec2.DescribeVpcsInput{}
	result, err := client.DescribeVpcs(ctx, input)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to list VPCs: " + err.Error()})
		return
	}

	var vpcs []map[string]interface{}
	for _, vpc := range result.Vpcs {
		name := ""
		for _, tag := range vpc.Tags {
			if aws.ToString(tag.Key) == "Name" {
				name = aws.ToString(tag.Value)
				break
			}
		}

		vpcs = append(vpcs, map[string]interface{}{
			"vpc_id":     aws.ToString(vpc.VpcId),
			"cidr_block": aws.ToString(vpc.CidrBlock),
			"state":      string(vpc.State),
			"name":       name,
			"is_default": vpc.IsDefault,
		})
	}

	c.JSON(http.StatusOK, gin.H{
		"vpcs":  vpcs,
		"count": len(vpcs),
	})
}

// ListAWSRegions returns all AWS regions
func ListAWSRegions(w http.ResponseWriter, r *http.Request) {
	regions, err := utils.GetAllAWSRegions()
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to list AWS regions: "+err.Error())
		return
	}

	currentRegion := utils.GetCurrentRegion()

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"regions":        regions,
		"current_region": currentRegion,
		"count":          len(regions),
	})
}

// fetchInstancesFromRegion fetches instances from a specific region
func fetchInstancesFromRegion(region string) ([]map[string]interface{}, error) {
	ctx := context.TODO()
	return fetchInstancesFromRegionWithContext(ctx, region)
}

// fetchInstancesFromRegionWithContext fetches instances from a specific region with context
func fetchInstancesFromRegionWithContext(ctx context.Context, region string) ([]map[string]interface{}, error) {
	client, err := utils.GetEC2ClientForRegion(region)
	if err != nil {
		return nil, err
	}

	var instances []map[string]interface{}
	var nextToken *string

	for {
		// Check if context is cancelled
		select {
		case <-ctx.Done():
			return instances, ctx.Err()
		default:
		}

		input := &ec2.DescribeInstancesInput{
			MaxResults: aws.Int32(100),
		}
		if nextToken != nil {
			input.NextToken = nextToken
		}

		result, err := client.DescribeInstances(ctx, input)
		if err != nil {
			return nil, err
		}

		for _, reservation := range result.Reservations {
			for _, instance := range reservation.Instances {
				instanceName := ""
				for _, tag := range instance.Tags {
					if aws.ToString(tag.Key) == "Name" {
						instanceName = aws.ToString(tag.Value)
						break
					}
				}

				instanceData := map[string]interface{}{
					"instance_id":   aws.ToString(instance.InstanceId),
					"name":          instanceName,
					"state":         string(instance.State.Name),
					"platform":      aws.ToString(instance.PlatformDetails),
					"architecture":  string(instance.Architecture),
					"instance_type": string(instance.InstanceType),
					"region":        region,
				}

				instances = append(instances, instanceData)
			}
		}

		if result.NextToken == nil {
			break
		}
		nextToken = result.NextToken
	}

	return instances, nil
}

// ListEC2InstancesAllRegions fetches instances from all regions in parallel
func ListEC2InstancesAllRegions(w http.ResponseWriter, r *http.Request) {
	regions, err := utils.GetAllAWSRegions()
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to get regions: "+err.Error())
		return
	}

	type regionResult struct {
		region    string
		instances []map[string]interface{}
		err       error
	}

	resultsChan := make(chan regionResult, len(regions))

	// Query all regions in parallel with timeout
	for _, region := range regions {
		go func(r string) {
			// Create context with timeout for each region
			ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
			defer cancel()

			instances, err := fetchInstancesFromRegionWithContext(ctx, r)
			resultsChan <- regionResult{
				region:    r,
				instances: instances,
				err:       err,
			}
		}(region)
	}

	// Collect results with overall timeout
	var allInstances []map[string]interface{}
	var failedRegions []string
	regionsQueried := make([]string, 0)

	// Set overall timeout for collecting results
	timeout := time.After(10 * time.Second)
	collected := 0

	for collected < len(regions) {
		select {
		case result := <-resultsChan:
			collected++
			if result.err != nil {
				failedRegions = append(failedRegions, result.region)
				continue
			}
			if len(result.instances) > 0 {
				allInstances = append(allInstances, result.instances...)
				regionsQueried = append(regionsQueried, result.region)
			}
		case <-timeout:
			// Timeout reached, return what we have so far
			goto done
		}
	}

done:
	response := map[string]interface{}{
		"instances":       allInstances,
		"count":           len(allInstances),
		"regions_queried": regionsQueried,
	}

	if len(failedRegions) > 0 {
		response["failed_regions"] = failedRegions
	}

	respondJSON(w, http.StatusOK, response)
}

// GetEC2Dashboard returns aggregated EC2 statistics across all regions
func GetEC2Dashboard(w http.ResponseWriter, r *http.Request) {
	regions, err := utils.GetAllAWSRegions()
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to get regions: "+err.Error())
		return
	}

	type regionResult struct {
		region    string
		instances []map[string]interface{}
		err       error
	}

	resultsChan := make(chan regionResult, len(regions))

	// Query all regions in parallel with timeout
	for _, region := range regions {
		go func(r string) {
			// Create context with timeout for each region
			ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
			defer cancel()

			instances, err := fetchInstancesFromRegionWithContext(ctx, r)
			resultsChan <- regionResult{
				region:    r,
				instances: instances,
				err:       err,
			}
		}(region)
	}

	// Collect and aggregate results with overall timeout
	instancesByRegion := make(map[string]int)
	instancesByState := make(map[string]int)
	totalInstances := 0
	regionsWithInstances := make([]string, 0)
	failedRegions := make([]string, 0)

	// Set overall timeout for collecting results
	timeout := time.After(10 * time.Second)
	collected := 0

	for collected < len(regions) {
		select {
		case result := <-resultsChan:
			collected++
			if result.err != nil {
				failedRegions = append(failedRegions, result.region)
				continue
			}

			if len(result.instances) > 0 {
				instancesByRegion[result.region] = len(result.instances)
				regionsWithInstances = append(regionsWithInstances, result.region)
				totalInstances += len(result.instances)

				// Count by state
				for _, instance := range result.instances {
					state := instance["state"].(string)
					instancesByState[state]++
				}
			}
		case <-timeout:
			// Timeout reached, return what we have so far
			goto done
		}
	}

done:
	currentRegion := utils.GetCurrentRegion()

	response := map[string]interface{}{
		"total_instances":        totalInstances,
		"regions_with_instances": len(regionsWithInstances),
		"current_region":         currentRegion,
		"instances_by_region":    instancesByRegion,
		"instances_by_state":     instancesByState,
		"regions":                regionsWithInstances,
	}

	// Only include failed regions if there are any
	if len(failedRegions) > 0 {
		response["failed_regions"] = failedRegions
	}

	respondJSON(w, http.StatusOK, response)
}
