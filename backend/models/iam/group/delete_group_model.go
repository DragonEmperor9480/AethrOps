package group

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"strings"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/service/iam"
)

func DeleteGroupModel(groupname string) {
	client := utils.GetIAMClient()
	ctx := context.TODO()

	// Check if group exists
	utils.ShowProcessingAnimation("Checking group existence...")
	getGroupInput := &iam.GetGroupInput{
		GroupName: &groupname,
	}
	getGroupOutput, err := client.GetGroup(ctx, getGroupInput)
	if err != nil {
		utils.StopAnimation()
		fmt.Println(utils.Red + utils.Bold + "Error: Group '" + groupname + "' does not exist." + utils.Reset)
		return
	}
	utils.StopAnimation()

	utils.ShowProcessingAnimation("Checking attached policies and users...")

	// Fetch attached policies
	listPoliciesInput := &iam.ListAttachedGroupPoliciesInput{
		GroupName: &groupname,
	}
	policiesOutput, _ := client.ListAttachedGroupPolicies(ctx, listPoliciesInput)
	var policies []string
	for _, policy := range policiesOutput.AttachedPolicies {
		if policy.PolicyArn != nil {
			policies = append(policies, *policy.PolicyArn)
		}
	}

	// Fetch users
	var users []string
	for _, user := range getGroupOutput.Users {
		if user.UserName != nil {
			users = append(users, *user.UserName)
		}
	}

	utils.StopAnimation()

	if len(policies) > 0 || len(users) > 0 {
		fmt.Println(utils.Yellow + "Group '" + groupname + "' has the following dependencies:" + utils.Reset)
		if len(policies) > 0 {
			fmt.Println(utils.Yellow+"- Policies:", strings.Join(policies, ", ")+utils.Reset)
		}
		if len(users) > 0 {
			fmt.Println(utils.Yellow+"- Users:", strings.Join(users, ", ")+utils.Reset)
		}
		fmt.Print(utils.Bold + "\nDo you want to detach policies and remove users before deleting? (y/n): " + utils.Reset)

		reader := bufio.NewReader(os.Stdin)
		input, _ := reader.ReadString('\n')
		if strings.TrimSpace(strings.ToLower(input)) != "y" {
			fmt.Println(utils.Red + utils.Bold + "Group deletion aborted." + utils.Reset)
			return
		}
	}

	// Detach policies
	if len(policies) > 0 {
		utils.ShowProcessingAnimation("Detaching policies...")
		for _, policyArn := range policies {
			detachInput := &iam.DetachGroupPolicyInput{
				GroupName: &groupname,
				PolicyArn: &policyArn,
			}
			_, err := client.DetachGroupPolicy(ctx, detachInput)
			if err != nil {
				fmt.Println(utils.Red + utils.Bold + "Failed to detach policy: " + policyArn + " (" + err.Error() + ")" + utils.Reset)
			} else {
				fmt.Println(utils.Green + "Detached policy: " + policyArn + utils.Reset)
			}
		}
		utils.StopAnimation()
		fmt.Println(utils.Yellow + "Detached all managed policies from '" + groupname + "'." + utils.Reset)
	}

	// Remove users
	if len(users) > 0 {
		utils.ShowProcessingAnimation("Removing users from group...")
		for _, user := range users {
			removeUserInput := &iam.RemoveUserFromGroupInput{
				GroupName: &groupname,
				UserName:  &user,
			}
			client.RemoveUserFromGroup(ctx, removeUserInput)
		}
		utils.StopAnimation()
		fmt.Println(utils.Yellow + "Removed all users from '" + groupname + "'." + utils.Reset)
	}

	// Delete group
	utils.ShowProcessingAnimation("Deleting group '" + groupname + "'...")
	deleteInput := &iam.DeleteGroupInput{
		GroupName: &groupname,
	}
	_, err = client.DeleteGroup(ctx, deleteInput)
	utils.StopAnimation()

	if err != nil {
		fmt.Println(utils.Red + utils.Bold + "Error: Failed to delete group '" + groupname + "'." + utils.Reset)
	} else {
		fmt.Println(utils.Green + utils.Bold + "Group '" + groupname + "' deleted successfully!" + utils.Reset)
	}
}
