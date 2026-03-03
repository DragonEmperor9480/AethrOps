package s3

import (
	"fmt"

	"github.com/DragonEmperor9480/AethrOps/utils"
)

func ShowS3Menu() {
	fmt.Println(utils.Green + "┌──────────────────────────────────────────────┐" + utils.Reset)
	fmt.Println(utils.Green + "│" + utils.Reset + "         " + utils.Bold + utils.Cyan + "AWS S3 MANAGEMENT CONSOLE" + utils.Reset + "            " + utils.Green + "│" + utils.Reset)
	fmt.Println(utils.Green + "└──────────────────────────────────────────────┘" + utils.Reset)
	fmt.Println()
	fmt.Println(utils.Bold + utils.Yellow + "Choose an option below:" + utils.Reset)
	fmt.Println()
	fmt.Println("  " + utils.Bold + "1)" + utils.Reset + "  Create S3 Bucket")
	fmt.Println("  " + utils.Bold + "2)" + utils.Reset + "  List S3 Buckets")
	fmt.Println("  " + utils.Bold + "3)" + utils.Reset + "  Delete S3 Bucket")
	fmt.Println("  " + utils.Bold + "4)" + utils.Reset + "  Browse S3 Bucket (TUI)")
	fmt.Println("  " + utils.Bold + "5)" + utils.Reset + "  Enable/Suspend Versioning on Bucket")
	fmt.Println("  " + utils.Bold + "6)" + utils.Reset + "  Enable/Disable MFA Delete on Bucket")
	fmt.Println("  " + utils.Bold + "7)" + utils.Reset + "  Back to Main Menu")
	fmt.Println()
}
