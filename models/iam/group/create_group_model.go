package group

import (
	"context"
	"fmt"
	"strings"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/service/iam"
)

func CreateIAMGroup(groupname string) {
	// Start animation in background
	utils.ShowProcessingAnimation("Creating IAM Group")

	// Get AWS IAM client
	client := utils.GetIAMClient()
	ctx := context.TODO()

	// Create group using AWS SDK
	input := &iam.CreateGroupInput{
		GroupName: &groupname,
	}

	_, err := client.CreateGroup(ctx, input)

	// Stop animation and print a newline
	utils.StopAnimation()
	fmt.Println()

	// Handle output
	if err != nil {
		if strings.Contains(err.Error(), "EntityAlreadyExists") {
			fmt.Println(utils.Bold + utils.Red + "Error: Group '" + groupname + "' already exists!" + utils.Reset)
		} else {
			fmt.Println(utils.Yellow + "Unexpected error occurred:" + utils.Reset)
			fmt.Println(err.Error())
		}
	} else {
		fmt.Println(utils.Bold + utils.Green + "Group '" + groupname + "' created successfully!" + utils.Reset)
	}
}
