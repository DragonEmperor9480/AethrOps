package user

import (
	"os/exec"
	"strings"

	utils "github.com/DragonEmperor9480/AethrOps/utils"
)

func UserExistsOrNotModel(username string) bool {
	utils.ShowProcessingAnimation("Checking if user exists: " + username)
	checkCmd := exec.Command("aws", "iam", "get-user", "--user-name", username)
	output, _ := checkCmd.CombinedOutput()
	utils.StopAnimation()
	if strings.Contains(string(output), "NoSuchEntity") {
		utils.StopAnimation()
		return false
	}
	return true

}
