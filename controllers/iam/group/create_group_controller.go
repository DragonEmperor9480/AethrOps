package group

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	iam_group "github.com/DragonEmperor9480/AethrOps/models/iam/group"
	"github.com/DragonEmperor9480/AethrOps/utils"
)

func CreateIAMGroupController() {
	reader := bufio.NewReader(os.Stdin)

	fmt.Print("Enter Groupname for new IAM Group: ")
	input, _ := reader.ReadString('\n')
	groupname := strings.TrimSpace(input)

	if groupname == "" {
		fmt.Println(utils.Bold + utils.Red + "Please enter a valid group name" + utils.Reset)
		return
	}

	iam_group.CreateIAMGroup(groupname)
}
