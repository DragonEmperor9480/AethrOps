package utils

import (
	"fmt"

	"github.com/DragonEmperor9480/aws_cli_manager/models"
)

func GetVersion() {
	info := models.GetVersion()
	fmt.Println(Bold + Magenta + "AethrOps" + Reset)
	fmt.Println("Version:", info.Version)
	fmt.Println("Running on:", info.OSName)
}
