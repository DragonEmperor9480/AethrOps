package user

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	user_model "github.com/DragonEmperor9480/AethrOps/models/iam/user"
	"github.com/DragonEmperor9480/AethrOps/utils"
)

func UpdateUserPasswordController() {
	ListUsersController()

	reader := bufio.NewReader(os.Stdin)

	fmt.Print("Enter Username to update password for: ")
	input, _ := reader.ReadString('\n')
	username := strings.TrimSpace(input)

	if username == "" {
		fmt.Println(utils.Bold + utils.Red + "Please enter a valid username." + utils.Reset)
		return
	}

	fmt.Print("Enter New Password for the user: ")
	input, _ = reader.ReadString('\n')
	password := strings.TrimSpace(input)

	if password == "" {
		fmt.Println(utils.Bold + utils.Red + "Please enter a valid password." + utils.Reset)
		return
	}

	user_model.UpdateUserPasswordModel(username, password)

}
