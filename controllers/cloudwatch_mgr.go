package controllers

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	cloudwatch "github.com/DragonEmperor9480/AethrOps/controllers/cloudwatch"
	"github.com/DragonEmperor9480/AethrOps/utils"
	cloudwatchview "github.com/DragonEmperor9480/AethrOps/views/cloudwatch"
)

func CloudWatch_mgr() {
	reader := bufio.NewReader(os.Stdin)

	for {
		cloudwatchview.ShowCloudWatchMenu()

		fmt.Print("Enter your choice: ")
		input, _ := reader.ReadString('\n')
		input = strings.TrimSpace(input)

		switch input {
		case "1":
			cloudwatch.LiveTailLambdaLogs()
			utils.Bk()
		case "2":
			// Back to main menu
			fmt.Println("Returning to Main Menu...")
			return
		default:
			fmt.Println(utils.Red + "Invalid Input. Please try again." + utils.Reset)
			utils.Bk()
		}
	}
}
