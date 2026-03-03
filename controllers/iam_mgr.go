package controllers

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	group "github.com/DragonEmperor9480/AethrOps/controllers/iam/group"
	user "github.com/DragonEmperor9480/AethrOps/controllers/iam/user"
	"github.com/DragonEmperor9480/AethrOps/utils"
	iamview "github.com/DragonEmperor9480/AethrOps/views/iam"
)

func IAM_mgr() {
	reader := bufio.NewReader(os.Stdin)

	for {
		iamview.ShowIAMMenu()

		fmt.Print("Choose an option: ")
		input, _ := reader.ReadString('\n')
		input = strings.TrimSpace(input)

		switch input {
		case "1":
			user.CreateIAMUserController()
			utils.Bk()
		case "2":
			user.ListUsersController()
			utils.Bk()
		case "3":
			group.AddUserToGroupController()
			utils.Bk()
		case "4":
			user.DeleteIAMUserController()
			utils.Bk()
		case "5":
			user.SetInitialUserPassword()
			utils.Bk()
		case "6":
			user.UpdateUserPasswordController()
			utils.Bk()
		case "7":
			user.CreateAccessKeyForUserController()
			utils.Bk()
		case "8":
			user.ListAccessKeysForUserController()
		case "9":
			group.CreateIAMGroupController()
			utils.Bk()
		case "10":
			group.ListGroupsController()
			utils.Bk()
		case "11":
			group.ListUsersInGroupController()
			utils.Bk()
		case "12":
			group.ListUserGroupsController()
			utils.Bk()
		case "13":
			group.DeleteIamGroupController()
			utils.Bk()
		case "14":
			group.RemoveUserFromGroupController()
			utils.Bk()
		case "15":
			fmt.Println("Returning to Main Menu...")
			utils.ClearScreen()
			return
		default:
			fmt.Println(utils.Red + "Invalid input. Please try again." + utils.Reset)
			utils.Bk()
		}
	}
}
