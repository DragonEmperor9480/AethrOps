package user

import (
	"context"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/iam"
)

// AccessKeyInfo represents an access key
type AccessKeyInfo struct {
	AccessKeyID string `json:"access_key_id"`
	Status      string `json:"status"`
	CreateDate  string `json:"create_date"`
	UserName    string `json:"user_name"`
}

// ListAccessKeysForUserModel lists access keys for a user
func ListAccessKeysForUserModel(username string) ([]AccessKeyInfo, error) {
	ctx := context.TODO()
	result, err := utils.IAMClient.ListAccessKeys(ctx, &iam.ListAccessKeysInput{
		UserName: aws.String(username),
	})

	if err != nil {
		return nil, err
	}

	keys := make([]AccessKeyInfo, 0, len(result.AccessKeyMetadata))
	for _, key := range result.AccessKeyMetadata {
		keys = append(keys, AccessKeyInfo{
			AccessKeyID: aws.ToString(key.AccessKeyId),
			Status:      string(key.Status),
			CreateDate:  key.CreateDate.String(),
			UserName:    aws.ToString(key.UserName),
		})
	}

	return keys, nil
}
