package group

import (
	"fmt"

	model "github.com/DragonEmperor9480/AethrOps/models/iam/group"
	"github.com/DragonEmperor9480/AethrOps/utils"
	view "github.com/DragonEmperor9480/AethrOps/views/iam/group"
)

func ListGroupsController() {
	utils.ShowProcessingAnimation("Loading IAM Groups")
	output, err := model.FetchIAMGroups()
	utils.StopAnimation()
	fmt.Println()

	if err != nil {
		fmt.Println(utils.Bold + utils.Red + "Error fetching IAM groups!" + utils.Reset)
		fmt.Println(output)
		return
	}

	view.ShowGroupsTable(output)
}
