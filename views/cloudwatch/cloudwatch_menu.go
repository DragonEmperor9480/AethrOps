package cloudwatch

import (
	"fmt"

	"github.com/DragonEmperor9480/AethrOps/utils"
)

func ShowCloudWatchMenu() {
	fmt.Println()
	fmt.Println(utils.Bold + utils.Cyan + "CloudWatch Management" + utils.Reset)
	fmt.Println("────────────────────────────────────")
	fmt.Println(utils.Bold + utils.Blue + "[1]" + utils.Reset + " Live Tail Lambda Logs")
	fmt.Println(utils.Bold + utils.Red + "[2]" + utils.Reset + " Back to Main Menu")
	fmt.Println("────────────────────────────────────")
}
