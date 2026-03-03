package user

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	create_user_model "github.com/DragonEmperor9480/AethrOps/models/iam/user"
	"github.com/DragonEmperor9480/AethrOps/utils"
)

func CreateIAMUserController() {
	reader := bufio.NewReader(os.Stdin)

	fmt.Print("Enter Username for new IAM User: ")
	input, _ := reader.ReadString('\n')
	username := strings.TrimSpace(input)

	if username == "" {
		fmt.Println(utils.Bold + utils.Red + "Please enter a valid name" + utils.Reset)
		return
	}

	utils.ShowProcessingAnimation("Creating IAM User")
	dataResponse, err := create_user_model.CreateIAMUser(username)
	utils.StopAnimation()

	switch dataResponse {
	case create_user_model.UserAlreadyExists:
		fmt.Println(utils.Bold + utils.Red + "Error: User '" + username + "' already exists!" + utils.Reset)
	case create_user_model.UserCreationError:
		fmt.Println(utils.Yellow + "Unexpected error occurred:" + utils.Reset)
		fmt.Println(err.Error())
	case create_user_model.UserCreatedSuccess:
		fmt.Println(utils.Bold + utils.Green + "User '" + username + "' created successfully!" + utils.Reset)
	}

	fmt.Print("Would you like to create set Initial password for the user? (y/n) (Default = n): ")
	saveChoice, _ := reader.ReadString('\n')
	saveChoice = strings.ToLower(strings.TrimSpace(saveChoice))
	if saveChoice == "y" {
		SetInitialUserPasswordDirect(username)
	} else {
		fmt.Println(utils.Bold + utils.Yellow + "Skipping Initial Password Setup" + utils.Reset)
	}
	fmt.Print("Would you like to create access key for the user? (y/n) (Default = n): ")
	saveChoice, _ = reader.ReadString('\n')
	saveChoice = strings.ToLower(strings.TrimSpace(saveChoice))
	if saveChoice == "y" {
		create_user_model.CreateAccessKeyForUserModel(username)
	} else {
		fmt.Println(utils.Bold + utils.Yellow + "Skipping Access Key Creation" + utils.Reset)
	}

}
