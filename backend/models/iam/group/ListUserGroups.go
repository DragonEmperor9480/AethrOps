package group

import (
	"context"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/service/iam"
)

func ListUserGroupsModel(username string) []string {
	client := utils.GetIAMClient()
	ctx := context.TODO()

	input := &iam.ListGroupsForUserInput{
		UserName: &username,
	}

	result, err := client.ListGroupsForUser(ctx, input)
	if err != nil {
		return []string{}
	}

	var groupNames []string
	for _, group := range result.Groups {
		if group.GroupName != nil {
			groupNames = append(groupNames, *group.GroupName)
		}
	}

	return groupNames
}
