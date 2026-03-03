package user

import (
	"context"
	"fmt"
	"strings"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/iam"
)

func FetchIAMUsers() (string, error) {
	ctx := context.TODO()
	result, err := utils.IAMClient.ListUsers(ctx, &iam.ListUsersInput{})
	if err != nil {
		return "", err
	}

	// Format output to match the old text format: UserName UserId CreateDate
	var output strings.Builder
	for _, user := range result.Users {
		line := fmt.Sprintf("%s\t%s\t%s\n",
			aws.ToString(user.UserName),
			aws.ToString(user.UserId),
			user.CreateDate.Format("2006-01-02T15:04:05Z"),
		)
		output.WriteString(line)
	}

	return output.String(), nil
}

func FetchOnlyUsernames() []string {
	ctx := context.TODO()
	result, err := utils.IAMClient.ListUsers(ctx, &iam.ListUsersInput{})
	if err != nil {
		return []string{}
	}

	// Extract just the usernames
	var usernames []string
	for _, user := range result.Users {
		usernames = append(usernames, aws.ToString(user.UserName))
	}

	return usernames
}
