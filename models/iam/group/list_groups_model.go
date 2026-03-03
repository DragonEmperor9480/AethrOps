package group

import (
	"context"
	"fmt"
	"strings"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/service/iam"
)

func FetchIAMGroups() (string, error) {
	client := utils.GetIAMClient()
	ctx := context.TODO()

	input := &iam.ListGroupsInput{}
	result, err := client.ListGroups(ctx, input)
	if err != nil {
		return "", err
	}

	var output strings.Builder
	for _, group := range result.Groups {
		groupName := ""
		groupID := ""
		createDate := ""

		if group.GroupName != nil {
			groupName = *group.GroupName
		}
		if group.GroupId != nil {
			groupID = *group.GroupId
		}
		if group.CreateDate != nil {
			createDate = group.CreateDate.Format("2006-01-02T15:04:05Z")
		}

		output.WriteString(fmt.Sprintf("%s\t%s\t%s\n", groupName, groupID, createDate))
	}

	return output.String(), nil
}

func FetchOnlyGroupNames() []string {
	client := utils.GetIAMClient()
	ctx := context.TODO()

	input := &iam.ListGroupsInput{}
	result, err := client.ListGroups(ctx, input)
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
