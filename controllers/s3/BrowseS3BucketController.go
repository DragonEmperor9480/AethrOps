package s3

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	"github.com/DragonEmperor9480/AethrOps/utils"
)

// BrowseS3BucketController handles the S3 bucket browser TUI
func BrowseS3BucketController() {
	reader := bufio.NewReader(os.Stdin)

	// List available buckets first
	ListS3Buckets()
	fmt.Println()

	// Prompt for bucket name
	fmt.Print("Enter bucket name: ")
	bucketInput, _ := reader.ReadString('\n')
	bucketName := strings.TrimSpace(bucketInput)

	if bucketName == "" {
		fmt.Println(utils.Red + "Bucket name cannot be empty." + utils.Reset)
		return
	}

	// Initialize and run the browser
	browser, err := NewS3Browser(bucketName)
	if err != nil {
		fmt.Println(utils.Red + "Failed to initialize S3 browser: " + err.Error() + utils.Reset)
		return
	}

	if err := browser.Run(); err != nil {
		fmt.Println(utils.Red + "Browser error: " + err.Error() + utils.Reset)
	}
}
