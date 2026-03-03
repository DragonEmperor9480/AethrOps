package user

import (
	"fmt"

	iam "github.com/DragonEmperor9480/AethrOps/models/iam/user"
	"github.com/DragonEmperor9480/AethrOps/utils"
	userview "github.com/DragonEmperor9480/AethrOps/views/iam/user"
)

func ListUsersController() {
	utils.ShowProcessingAnimation("Loading IAM Users")
	data, err := iam.FetchIAMUsers()
	utils.StopAnimation()

	if err != nil {
		fmt.Println(utils.Red + "Failed to fetch IAM users: " + err.Error() + utils.Reset)
		return
	}

	userview.RenderIAMUsersTable(data)
}
