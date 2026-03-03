// this shows how many groups a user is rsent in
package group

import (
	"fmt"

	"github.com/DragonEmperor9480/AethrOps/utils"
)

func ShowGroupsOfUser(username string, groups []string) bool{
	fmt.Println()
	fmt.Println(utils.Bold + utils.Cyan + "Groups assigned to user: " + username + utils.Reset)

	if len(groups) == 0 {
		fmt.Println(utils.Yellow + "This user is not part of any groups." + utils.Reset)
		return false
	}

	fmt.Println(utils.Bold + "┌────────────────────────────┐" + utils.Reset)
	fmt.Println(utils.Bold + "│        Group Names         │" + utils.Reset)
	fmt.Println(utils.Bold + "├────────────────────────────┤" + utils.Reset)

	for _, group := range groups {
		fmt.Printf(utils.Bold+"│ %-26s │\n"+utils.Reset, group)
	}

	fmt.Println(utils.Bold + "└────────────────────────────┘" + utils.Reset)
	return true
}
