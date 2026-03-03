package user

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"strings"

	"github.com/DragonEmperor9480/AethrOps/db_service"
	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/iam"
)

func UpdateUserPasswordModel(username, password string) {
	reader := bufio.NewReader(os.Stdin)

	ctx := context.TODO()
	_, err := utils.IAMClient.UpdateLoginProfile(ctx, &iam.UpdateLoginProfileInput{
		UserName: aws.String(username),
		Password: aws.String(password),
	})

	if err != nil {
		if strings.Contains(err.Error(), "NoSuchEntity") {
			fmt.Println(utils.Red + utils.Bold + "Error: The user '" + username + "' does not exist!" + utils.Reset)
		} else if strings.Contains(err.Error(), "PasswordPolicyViolation") {
			fmt.Println(utils.Red + utils.Bold + "Error: Password does not meet AWS policy requirements!" + utils.Reset)
			fmt.Println(utils.Yellow + "Password should include at least:\n" +
				"- One uppercase letter\n" +
				"- One lowercase letter\n" +
				"- One symbol (e.g., !@#$%^&*)\n" +
				"- One number (if required by your policy)\n" +
				"- Minimum length as per your account policy" + utils.Reset)
		} else {
			fmt.Println(utils.Red + utils.Bold + "Error occurred while updating password:" + utils.Reset)
			fmt.Println(err.Error())
		}
		return
	}

	fmt.Println(utils.Green + utils.Bold + " User password updated successfully!" + utils.Reset)

	//Save credentials
	fmt.Print(utils.Yellow + utils.Bold + "Would you like to save " + username + "'s credentials? (y/n): " + utils.Reset)
	saveChoice, _ := reader.ReadString('\n')
	saveChoice = strings.ToLower(strings.TrimSpace(saveChoice))

	if saveChoice == "y" {
		err := db_service.UpdateUserPassword(username, password)
		if err != nil {
			fmt.Println(utils.Red + utils.Bold + "Error updating credentials: " + err.Error() + utils.Reset)
			return
		}
		fmt.Println(utils.Green + utils.Bold + "✓ Credentials updated securely in database" + utils.Reset)
	}

	// Show credentials
	fmt.Println(utils.Cyan + utils.Bold + "\nGenerated Credentials:" + utils.Reset)
	fmt.Println("Username: " + utils.Bold + username + utils.Reset)
	fmt.Println("Password: " + utils.Bold + password + utils.Reset)
}
