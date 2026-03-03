package group

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	controller "github.com/DragonEmperor9480/AethrOps/controllers/iam/user"
	model "github.com/DragonEmperor9480/AethrOps/models/iam/group"
	"github.com/DragonEmperor9480/AethrOps/utils"
	view "github.com/DragonEmperor9480/AethrOps/views/iam/group"
)

func ListUserGroupsController() {
	reader := bufio.NewReader(os.Stdin)
	controller.ListUsersController()
	fmt.Print("Enter username: ")
	input, _ := reader.ReadString('\n')
	username := strings.TrimSpace(input)
	utils.ShowProcessingAnimation("Fetching IAM Groups for User")
	GetGroups := model.ListUserGroupsModel(username)
	utils.StopAnimation()
	view.ShowGroupsOfUser(username, GetGroups)

}
