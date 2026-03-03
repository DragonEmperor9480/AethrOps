package group

import (
	"fmt"

	"github.com/DragonEmperor9480/AethrOps/utils"
)

func ShowGroupUsersTable(groupname string, users []string) {
	fmt.Println()
	fmt.Println(utils.Bold + "Users in IAM Group: " + groupname + utils.Reset)
	fmt.Println(utils.Bold + "┌────────────────────────────┐" + utils.Reset)
	fmt.Println(utils.Bold + "│         IAM Users          │" + utils.Reset)
	fmt.Println(utils.Bold + "├────────────────────────────┤" + utils.Reset)

	for _, user := range users {
		fmt.Printf(utils.Bold+"│ %-26s │\n"+utils.Reset, user)
	}

	fmt.Println(utils.Bold + "└────────────────────────────┘" + utils.Reset)
}
