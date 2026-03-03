package group

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	groupModel "github.com/DragonEmperor9480/AethrOps/models/iam/group"
	"github.com/DragonEmperor9480/AethrOps/utils"
)

func DeleteIamGroupController() {
	ListGroupsController()
	fmt.Println()
	reader := bufio.NewReader(os.Stdin)

	fmt.Print("Enter the group name you want to delete: ")
	input, _ := reader.ReadString('\n')
	groupname := strings.TrimSpace(input)

	if groupname == "" {
		fmt.Println(utils.Red + utils.Bold + "Please enter a valid group name." + utils.Reset)
		return
	}

	groupModel.DeleteGroupModel(groupname)
}
