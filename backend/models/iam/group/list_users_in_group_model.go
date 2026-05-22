package group

import (
	"context"
	"fmt"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/iam"
)

// UserInGroup represents a user in a group
type UserInGroup struct {
	UserName   string `json:"user_name"`
	UserID     string `json:"user_id"`
	CreateDate string `json:"create_date"`
}

// ListUsersInGroupModel lists all users in a group
func ListUsersInGroupModel(groupname string) ([]UserInGroup, error) {
	client := utils.GetIAMClient()
	ctx := context.TODO()

	input := &iam.GetGroupInput{
		GroupName: &groupname,
	}

	result, err := client.GetGroup(ctx, input)
	if err != nil {
		return nil, fmt.Errorf("failed to get group: %w", err)
	}

	users := make([]UserInGroup, 0, len(result.Users))
	for _, user := range result.Users {
		users = append(users, UserInGroup{
			UserName:   aws.ToString(user.UserName),
			UserID:     aws.ToString(user.UserId),
			CreateDate: user.CreateDate.String(),
		})
	}

	return users, nil
}
