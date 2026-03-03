package user

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	model "github.com/DragonEmperor9480/AethrOps/models/iam/user"
)

func CreateAccessKeyForUserController() {
	reader := bufio.NewReader(os.Stdin)
	ListUsersController()
	fmt.Print("Enter IAM username to create access key for: ")
	input, _ := reader.ReadString('\n')
	username := strings.TrimSpace(input)
	model.CreateAccessKeyForUserModel(username)

}
