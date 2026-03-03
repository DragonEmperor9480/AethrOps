package user

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"strings"

	"github.com/DragonEmperor9480/AethrOps/utils"
	iamview "github.com/DragonEmperor9480/AethrOps/views/iam/user"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/iam"
)

func CreateAccessKeyForUserModel(username string) {
	cond := UserExistsOrNotModel(username)
	if !cond {
		fmt.Println(utils.Red + utils.Bold + "User does not exist." + utils.Reset)
		return
	}

	utils.ShowProcessingAnimation("Creating access key for user...")

	// Create access key using AWS SDK
	ctx := context.TODO()
	result, err := utils.IAMClient.CreateAccessKey(ctx, &iam.CreateAccessKeyInput{
		UserName: aws.String(username),
	})

	utils.StopAnimation()

	if err != nil {
		fmt.Println("Error creating access key:", err.Error())
		return
	}

	// Convert result to JSON format (to match old view format)
	accessKeyData := map[string]interface{}{
		"AccessKey": map[string]interface{}{
			"UserName":        aws.ToString(result.AccessKey.UserName),
			"AccessKeyId":     aws.ToString(result.AccessKey.AccessKeyId),
			"Status":          result.AccessKey.Status,
			"SecretAccessKey": aws.ToString(result.AccessKey.SecretAccessKey),
			"CreateDate":      result.AccessKey.CreateDate,
		},
	}
	jsonOutput, _ := json.MarshalIndent(accessKeyData, "", "  ")

	accessKey, secretAccessKey := iamview.ShowAccessKeyView(string(jsonOutput))

	fmt.Print("Would you like to save the access key and secret access key? (y/n): ")
	reader := bufio.NewReader(os.Stdin)
	saveChoice, _ := reader.ReadString('\n')
	saveChoice = strings.ToLower(strings.TrimSpace(saveChoice))

	if saveChoice == "y" {
		// Save the access key and secret access key
		credentialsDir := "/home/" + os.Getenv("USER") + "/.config/awsmgr/user_AccessKey_Credentials"
		os.MkdirAll(credentialsDir, 0755)
		filePath := credentialsDir + "/" + username + "_access_key_credentials.txt"
		file, err := os.Create(filePath)
		if err != nil {
			fmt.Println("Error creating credentials file:", err)
			return
		}
		defer file.Close()

		_, err = file.WriteString(" User: " + username + "\n")
		if err != nil {
			fmt.Println("Error writing to credentials file:", err)
			return
		}
		_, err = file.WriteString("Access Key: " + accessKey + "\n")
		if err != nil {
			fmt.Println("Error writing to credentials file:", err)
			return
		}
		_, err = file.WriteString("Secret Access Key: " + secretAccessKey + "\n")
		if err != nil {
			fmt.Println("Error writing to credentials file:", err)
			return
		}
		fmt.Println(utils.Green + utils.Bold + "Access key and secret access key saved successfully at: " + filePath + utils.Reset)
	} else {
		fmt.Println(utils.Yellow + utils.Bold + "skipped saving credentials." + utils.Reset)
	}

}
