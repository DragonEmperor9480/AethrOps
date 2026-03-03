package user

import (
	"bufio"
	"fmt"
	"os"
	"strings"
	"unicode"

	"github.com/DragonEmperor9480/AethrOps/db_service"
	user_model "github.com/DragonEmperor9480/AethrOps/models/iam/user"
	"github.com/DragonEmperor9480/AethrOps/utils"
)

// validatePassword checks if password meets requirements
func validatePassword(password string) (bool, string) {
	if len(password) < 8 {
		return false, "Password must be at least 8 characters long"
	}

	var (
		hasUpper  bool
		hasLower  bool
		hasNumber bool
	)

	for _, char := range password {
		switch {
		case unicode.IsUpper(char):
			hasUpper = true
		case unicode.IsLower(char):
			hasLower = true
		case unicode.IsNumber(char):
			hasNumber = true
		}
	}

	if !hasUpper {
		return false, "Password must contain at least one uppercase letter"
	}
	if !hasLower {
		return false, "Password must contain at least one lowercase letter"
	}
	if !hasNumber {
		return false, "Password must contain at least one number"
	}

	return true, ""
}

func SetInitialUserPassword() {
	ListUsersController()

	reader := bufio.NewReader(os.Stdin)

	fmt.Print("Enter Username to set password for: ")
	input, _ := reader.ReadString('\n')
	username := strings.TrimSpace(input)

	if username == "" {
		fmt.Println(utils.Bold + utils.Red + "Please enter a valid username." + utils.Reset)
		return
	}

	if !user_model.UserExistsOrNotModel(username) {
		return
	}

	fmt.Print("Enter Password for the user: ")
	input, _ = reader.ReadString('\n')
	password := strings.TrimSpace(input)

	if password == "" {
		fmt.Println(utils.Bold + utils.Red + "Please enter a valid password." + utils.Reset)
		return
	}

	// Validate password
	if valid, errMsg := validatePassword(password); !valid {
		fmt.Println(utils.Bold + utils.Red + "Error: " + errMsg + utils.Reset)
		fmt.Println(utils.Yellow + "Password requirements:\n" +
			"- At least 8 characters long\n" +
			"- At least one uppercase letter\n" +
			"- At least one lowercase letter\n" +
			"- At least one number" + utils.Reset)
		return
	}

	// Ask for password reset requirement
	fmt.Print(utils.Yellow + utils.Bold + "Allow password reset at first login? (y/n): " + utils.Reset)
	choice, _ := reader.ReadString('\n')
	choice = strings.ToLower(strings.TrimSpace(choice))
	requireReset := choice == "y"

	if requireReset {
		fmt.Println(utils.Bold + utils.Yellow + "Initial password reset is enabled." + utils.Reset)
	} else {
		fmt.Println(utils.Bold + utils.Yellow + "Initial password reset is disabled." + utils.Reset)
	}

	utils.ShowProcessingAnimation("Creating password...")
	status, err := user_model.SetInitialUserPasswordModel(username, password, requireReset)
	utils.StopAnimation()

	switch status {
	case user_model.PasswordUserNotFound:
		fmt.Println(utils.Red + utils.Bold + "Error: The user '" + username + "' does not exist!" + utils.Reset)
		return
	case user_model.PasswordPolicyViolation:
		fmt.Println(utils.Red + utils.Bold + "Error: Password does not meet AWS policy requirements!" + utils.Reset)
		fmt.Println(utils.Yellow + "Your AWS account may have additional password policy requirements." + utils.Reset)
		return
	case user_model.PasswordAlreadyExists:
		fmt.Println(utils.Red + utils.Bold + "Error: Password for user '" + username + "' already exists!" + utils.Reset)
		return
	case user_model.PasswordCreationError:
		fmt.Println(utils.Red + utils.Bold + "Error occurred while creating password:" + utils.Reset)
		fmt.Println(err.Error())
		return
	case user_model.PasswordCreatedSuccess:
		fmt.Println(utils.Green + utils.Bold + "✓ User password created successfully!" + utils.Reset)
	}

	// Save credentials
	fmt.Print(utils.Yellow + utils.Bold + "Would you like to save " + username + "'s credentials? (y/n): " + utils.Reset)
	saveChoice, _ := reader.ReadString('\n')
	saveChoice = strings.ToLower(strings.TrimSpace(saveChoice))

	if saveChoice == "y" {
		err := db_service.SaveUserCredential(username, password)
		if err != nil {
			fmt.Println(utils.Red + utils.Bold + "Error saving credentials: " + err.Error() + utils.Reset)
		} else {
			fmt.Println(utils.Green + utils.Bold + "✓ Credentials saved securely to database" + utils.Reset)
		}
	}

	// Show credentials
	fmt.Println(utils.Cyan + utils.Bold + "\nGenerated Credentials:" + utils.Reset)
	fmt.Println("Username: " + utils.Bold + username + utils.Reset)
	fmt.Println("Password: " + utils.Bold + password + utils.Reset)
}

func SetInitialUserPasswordDirect(username string) {
	reader := bufio.NewReader(os.Stdin)

	fmt.Print("Enter Password for the user: ")
	input, _ := reader.ReadString('\n')
	password := strings.TrimSpace(input)

	if password == "" {
		fmt.Println(utils.Bold + utils.Red + "Failed to create password since it was left empty" + utils.Reset)
		return
	}

	// Validate password
	if valid, errMsg := validatePassword(password); !valid {
		fmt.Println(utils.Bold + utils.Red + "Error: " + errMsg + utils.Reset)
		fmt.Println(utils.Yellow + "Password requirements:\n" +
			"- At least 8 characters long\n" +
			"- At least one uppercase letter\n" +
			"- At least one lowercase letter\n" +
			"- At least one number" + utils.Reset)
		return
	}

	// Ask for password reset requirement
	fmt.Print(utils.Yellow + utils.Bold + "Allow password reset at first login? (y/n): " + utils.Reset)
	choice, _ := reader.ReadString('\n')
	choice = strings.ToLower(strings.TrimSpace(choice))
	requireReset := choice == "y"

	if requireReset {
		fmt.Println(utils.Bold + utils.Yellow + "Initial password reset is enabled." + utils.Reset)
	} else {
		fmt.Println(utils.Bold + utils.Yellow + "Initial password reset is disabled." + utils.Reset)
	}

	utils.ShowProcessingAnimation("Creating password...")
	status, err := user_model.SetInitialUserPasswordModel(username, password, requireReset)
	utils.StopAnimation()

	switch status {
	case user_model.PasswordUserNotFound:
		fmt.Println(utils.Red + utils.Bold + "Error: The user '" + username + "' does not exist!" + utils.Reset)
		return
	case user_model.PasswordPolicyViolation:
		fmt.Println(utils.Red + utils.Bold + "Error: Password does not meet AWS policy requirements!" + utils.Reset)
		fmt.Println(utils.Yellow + "Your AWS account may have additional password policy requirements." + utils.Reset)
		return
	case user_model.PasswordAlreadyExists:
		fmt.Println(utils.Red + utils.Bold + "Error: Password for user '" + username + "' already exists!" + utils.Reset)
		return
	case user_model.PasswordCreationError:
		fmt.Println(utils.Red + utils.Bold + "Error occurred while creating password:" + utils.Reset)
		fmt.Println(err.Error())
		return
	case user_model.PasswordCreatedSuccess:
		fmt.Println(utils.Green + utils.Bold + "User password created successfully!" + utils.Reset)
	}

	// Save credentials
	fmt.Print(utils.Yellow + utils.Bold + "Would you like to save " + username + "'s credentials? (y/n): " + utils.Reset)
	saveChoice, _ := reader.ReadString('\n')
	saveChoice = strings.ToLower(strings.TrimSpace(saveChoice))

	if saveChoice == "y" {
		err := db_service.SaveUserCredential(username, password)
		if err != nil {
			fmt.Println(utils.Red + utils.Bold + "Error saving credentials: " + err.Error() + utils.Reset)
		} else {
			fmt.Println(utils.Green + utils.Bold + "Credentials saved securely to database" + utils.Reset)
		}
	}

	// Show credentials
	fmt.Println(utils.Cyan + utils.Bold + "\nGenerated Credentials:" + utils.Reset)
	fmt.Println("Username: " + utils.Bold + username + utils.Reset)
	fmt.Println("Password: " + utils.Bold + password + utils.Reset)
}
