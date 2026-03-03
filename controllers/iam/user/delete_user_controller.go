package user

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	iam_user "github.com/DragonEmperor9480/AethrOps/models/iam/user"
	"github.com/DragonEmperor9480/AethrOps/utils"
)

func DeleteIAMUserController() {
	reader := bufio.NewReader(os.Stdin)
	ListUsersController()

	fmt.Print("Enter IAM username you want to delete: ")
	input, _ := reader.ReadString('\n')
	username := strings.TrimSpace(input)

	if username == "" {
		fmt.Println(utils.Bold + utils.Red + "Please enter a valid name" + utils.Reset)
		return
	}

	iam_user.DeleteIAMUser(username)

}
