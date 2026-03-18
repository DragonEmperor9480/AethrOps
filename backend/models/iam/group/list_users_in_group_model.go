package group

import (
	"context"
	"fmt"
	"strings"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/service/iam"
)

func ListUsersInGroupModel(groupname string) {
	client := utils.GetIAMClient()
	ctx := context.TODO()

	input := &iam.GetGroupInput{
		GroupName: &groupname,
	}

	result, err := client.GetGroup(ctx, input)

	if err != nil {
		if strings.Contains(err.Error(), "NoSuchEntity") {
			fmt.Println(utils.Bold + utils.Red + "Group '" + groupname + "' does not exist!" + utils.Reset)
		} else {
			fmt.Println(utils.Bold + utils.Red + "Error: " + err.Error() + utils.Reset)
		}
		return
	}

	if len(result.Users) == 0 {
		fmt.Println(utils.Bold + utils.Yellow + "No users found in group '" + groupname + "'." + utils.Reset)
		return
	}
}
