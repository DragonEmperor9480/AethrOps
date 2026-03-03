package iamview

import (
	"fmt"
	"github.com/DragonEmperor9480/AethrOps/utils"
)

func ShowIAMMenu() {
	fmt.Print("\033[H\033[2J") // Clear screen
	fmt.Println(utils.Green + "┌──────────────────────────────────────────────┐" + utils.Reset)
	fmt.Println(utils.Green + "│" + utils.Reset + "        " + utils.Bold + utils.Cyan + "AWS IAM MANAGEMENT CONSOLE" + utils.Reset + "            " + utils.Green + "│" + utils.Reset)
	fmt.Println(utils.Green + "└──────────────────────────────────────────────┘" + utils.Reset)

	fmt.Println()
	fmt.Println(utils.Bold + utils.Yellow + "User Management:" + utils.Reset)
	fmt.Println("  " + utils.Bold + "1)" + utils.Reset + " Create IAM User")
	fmt.Println("  " + utils.Bold + "2)" + utils.Reset + " List IAM Users")
	fmt.Println("  " + utils.Bold + "3)" + utils.Reset + " Add User to a Group")
	fmt.Println("  " + utils.Bold + "4)" + utils.Reset + " Delete IAM User")
	fmt.Println("  " + utils.Bold + "5)" + utils.Reset + " Set Initial password for IAM user")
	fmt.Println("  " + utils.Bold + "6)" + utils.Reset + " Change password for IAM user")
	fmt.Println("  " + utils.Bold + "7)" + utils.Reset + " Create access key (BETA)")
	fmt.Println("  " + utils.Bold + "8)" + utils.Reset + " list access key(s) (WIP)")
	fmt.Println("  " + utils.Bold + "9)" + utils.Reset + " delete access key (TO DO)")

	fmt.Println()
	fmt.Println(utils.Bold + utils.Yellow + "Group Management:" + utils.Reset)
	fmt.Println("  " + utils.Bold + "9)" + utils.Reset + "  Create IAM Group")
	fmt.Println("  " + utils.Bold + "10)" + utils.Reset + " List IAM Groups")
	fmt.Println("  " + utils.Bold + "11)" + utils.Reset + " Check Total Users in a Group")
	fmt.Println("  " + utils.Bold + "12)" + utils.Reset + " List Groups a User Belongs To")
	fmt.Println("  " + utils.Bold + "13)" + utils.Reset + " Delete IAM Group")
	fmt.Println("  " + utils.Bold + "14)" + utils.Reset + " Remove User from Group")
	fmt.Println()
	fmt.Println("  " + utils.Bold + "15)" + utils.Reset + " Back to Main Menu")
	fmt.Println()
}
