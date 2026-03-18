package utils

import (
	"fmt"
	"time"
)

var animationRunning = false

func ShowProcessingAnimation(message string) {
	animationRunning = true
	go func() {
		frames := []string{"|", "/", "-", "\\"}
		i := 0
		for animationRunning {
			fmt.Printf("\r%s %s", Blue+message+Reset, frames[i%len(frames)])
			time.Sleep(100 * time.Millisecond)
			i++
		}
	}()
}

func StopAnimation() {
	animationRunning = false
	time.Sleep(150 * time.Millisecond) // Wait for goroutine to finish
	fmt.Print("\r                                                    \r") // Clear the line
}
