package user

import (
	"context"
	"encoding/json"

	"github.com/DragonEmperor9480/AethrOps/utils"
	user_view "github.com/DragonEmperor9480/AethrOps/views/iam/user"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/iam"
)

func ListAccessKeysForUserModel(username string) {
	utils.ShowProcessingAnimation("Listing access keys for user: " + username)

	ctx := context.TODO()
	result, err := utils.IAMClient.ListAccessKeys(ctx, &iam.ListAccessKeysInput{
		UserName: aws.String(username),
	})

	utils.StopAnimation()

	if err != nil {
		println("Error listing access keys:", err.Error())
		return
	}

	// Convert result to JSON format (to match old view format)
	accessKeysData := map[string]interface{}{
		"AccessKeyMetadata": []map[string]interface{}{},
	}

	for _, key := range result.AccessKeyMetadata {
		keyData := map[string]interface{}{
			"UserName":    aws.ToString(key.UserName),
			"AccessKeyId": aws.ToString(key.AccessKeyId),
			"Status":      key.Status,
			"CreateDate":  key.CreateDate,
		}
		accessKeysData["AccessKeyMetadata"] = append(
			accessKeysData["AccessKeyMetadata"].([]map[string]interface{}),
			keyData,
		)
	}

	jsonOutput, _ := json.MarshalIndent(accessKeysData, "", "  ")
	user_view.ListAccessKeysForUserView(string(jsonOutput))
}
