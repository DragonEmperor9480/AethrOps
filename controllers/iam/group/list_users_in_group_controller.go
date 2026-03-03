package group

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	group_model "github.com/DragonEmperor9480/AethrOps/models/iam/group"

	"github.com/DragonEmperor9480/AethrOps/utils"
)

func ListUsersInGroupController(){
	reader:=bufio.NewReader(os.Stdin)

	ListGroupsController()
	fmt.Print("Enter Group Name:")
	input,_:=reader.ReadString('\n')
	groupname:=strings.TrimSpace(input)

	if groupname == "" {
		fmt.Println(utils.Bold + utils.Red + "Please enter a valid username." + utils.Reset)
		return
	}

	group_model.ListUsersInGroupModel(groupname)

	


}