package utils

import (
	"fmt"
	"strings"
)

func InputChecker(input string) bool {
	if strings.TrimSpace(input) == "" {
		fmt.Println("Input cannot be empty. Please provide a valid input.")
		return false
	}
	return true
}
