package group

import (
	"context"
	"fmt"
	"strings"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/iam"
)

func AddUserToGroupModel(username, groupname string) {
	utils.ShowProcessingAnimation("Adding User to Group")

	ctx := context.TODO()
	_, err := utils.IAMClient.AddUserToGroup(ctx, &iam.AddUserToGroupInput{
		UserName:  aws.String(username),
		GroupName: aws.String(groupname),
	})

	utils.StopAnimation()
	fmt.Println()

	if err != nil {
		if strings.Contains(err.Error(), "NoSuchEntity") {
			fmt.Println(utils.Bold + utils.Red + "Error: Either the User or Group does not exist!" + utils.Reset)
		} else {
			fmt.Println(utils.Yellow + "Unexpected error occurred:" + utils.Reset)
			fmt.Println(err.Error())
		}
		return
	}

	fmt.Println(utils.Bold + utils.Green + "User '" + username + "' added to group '" + groupname + "' successfully!" + utils.Reset)
}
