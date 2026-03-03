package iamview

import (
	"fmt"
	"github.com/DragonEmperor9480/AethrOps/utils"
)

func ShowEC2Menu() {
	fmt.Print("\033[H\033[2J") // Clear screen
	fmt.Println(utils.Green + "┌──────────────────────────────────────────────┐" + utils.Reset)
	fmt.Println(utils.Green + "│" + utils.Reset + "        " + utils.Bold + utils.Cyan + "AWS EC2 MANAGEMENT CONSOLE" + utils.Reset + "            " + utils.Green + "│" + utils.Reset)
	fmt.Println(utils.Green + "└──────────────────────────────────────────────┘" + utils.Reset)

	fmt.Println()
	fmt.Println("  " + utils.Bold + "1)" + utils.Reset + " Launch EC2 Instance")
	fmt.Println("  " + utils.Bold + "2)" + utils.Reset + " Stop EC2 Instance")
	fmt.Println("  " + utils.Bold + "3)" + utils.Reset + " Terminate EC2 Instance")
	fmt.Println("  " + utils.Bold + "4)" + utils.Reset + " List all EC2 Instances")
	fmt.Println("  " + utils.Bold + "5)" + utils.Reset + " List All AMI")
	fmt.Println("  " + utils.Bold + "6)" + utils.Reset + " Attach Volume")
	fmt.Println("  " + utils.Bold + "7)" + utils.Reset + " Detach Volume")
	fmt.Println("  " + utils.Bold + "8)" + utils.Reset + " Create Snapshot")
	fmt.Println("  " + utils.Bold + "9)" + utils.Reset + " Delete Snapshot")
	fmt.Println()
}
