package group

import (
	"context"
	"fmt"
	"strings"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/service/iam"
)

func RemoveUserFromGroupModel(username, groupname string) {
	utils.ShowProcessingAnimation("Removing user '" + username + "' from group '" + groupname + "'")

	client := utils.GetIAMClient()
	ctx := context.TODO()

	input := &iam.RemoveUserFromGroupInput{
		GroupName: &groupname,
		UserName:  &username,
	}

	_, err := client.RemoveUserFromGroup(ctx, input)
	utils.StopAnimation()

	if err != nil {
		if strings.Contains(err.Error(), "NoSuchEntity") {
			fmt.Println(utils.Bold + utils.Red + "Error: Either the User or Group does not exist!" + utils.Reset)
		} else {
			fmt.Println(utils.Yellow + "Unexpected error occurred:" + utils.Reset)
			fmt.Println(err.Error())
		}
	} else {
		fmt.Println(utils.Bold + utils.Green + "User '" + username + "' removed from group '" + groupname + "' successfully!" + utils.Reset)
	}
}
