package utils

import (
	"fmt"
)

// ClearScreen clears the terminal screen.

func ClearScreen() {
	fmt.Print("\033[H\033[2J")
}
