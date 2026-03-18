package utils

import (
	"bufio"
	"fmt"
	"os"
)

func Bk() {
	fmt.Print("Press ENTER to go back...")
	reader := bufio.NewReader(os.Stdin)
	reader.ReadString('\n')
	fmt.Print("\033[H\033[2J") // Clear screen
}
