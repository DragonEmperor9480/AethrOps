package user

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	user_model "github.com/DragonEmperor9480/AethrOps/models/iam/user"
	"github.com/DragonEmperor9480/AethrOps/utils"
)

func ListAccessKeysForUserController() {
	ListUsersController()

	reader := bufio.NewReader(os.Stdin)
	fmt.Print("Enter Username to list access keys for: ")
	input, _ := reader.ReadString('\n')
	username := strings.TrimSpace(input)

	cond := user_model.UserExistsOrNotModel(username)
	if !cond {
		fmt.Println(utils.Yellow + utils.Bold + "User does not exist." + utils.Reset)
		utils.Bk()
		return
	}
	user_model.ListAccessKeysForUserModel(username)

}
