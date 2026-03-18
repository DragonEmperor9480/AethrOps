package user

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"strings"

	"github.com/DragonEmperor9480/AethrOps/utils"
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

	// Display access key information
	accessKey := aws.ToString(result.AccessKey.AccessKeyId)
	secretAccessKey := aws.ToString(result.AccessKey.SecretAccessKey)

	fmt.Println(utils.Green + utils.Bold + "\nAccess Key Created Successfully!" + utils.Reset)
	fmt.Println("User:", username)
	fmt.Println("Access Key ID:", accessKey)
	fmt.Println("Secret Access Key:", secretAccessKey)
	fmt.Println(utils.Yellow + "\nWARNING: This is the only time you can view the secret access key!" + utils.Reset)

	fmt.Print("\nWould you like to save the access key and secret access key? (y/n): ")
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
