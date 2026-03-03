package group

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	groupModel "github.com/DragonEmperor9480/AethrOps/models/iam/group"
	userModel "github.com/DragonEmperor9480/AethrOps/models/iam/user"
	"github.com/DragonEmperor9480/AethrOps/utils"
	views "github.com/DragonEmperor9480/AethrOps/views/iam/group"
)

func AddUserToGroupController() {
	utils.ShowProcessingAnimation("Fetching IAM Users and IAM Groups")
	users := userModel.FetchOnlyUsernames()
	groups := groupModel.FetchOnlyGroupNames()
	utils.StopAnimation()
	views.ShowUsersAndGroupsSideBySide(users, groups)

	reader := bufio.NewReader(os.Stdin)

	fmt.Print("Enter Username: ")
	input, _ := reader.ReadString('\n')
	username := strings.TrimSpace(input)

	fmt.Print("Enter Groupname: ")
	input, _ = reader.ReadString('\n')
	groupname := strings.TrimSpace(input)

	if username == "" || groupname == "" {
		fmt.Println(utils.Bold + utils.Red + "Both username and groupname must be provided!" + utils.Reset)
		return
	}

	groupModel.AddUserToGroupModel(username, groupname)
}
