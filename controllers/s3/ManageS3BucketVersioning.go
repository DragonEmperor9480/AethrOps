package s3

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	s3model "github.com/DragonEmperor9480/AethrOps/models/s3"
	"github.com/DragonEmperor9480/AethrOps/utils"
)

func S3BucketVersioningController() {
	reader := bufio.NewReader(os.Stdin)
	ListS3Buckets()

	fmt.Print("Enter the S3 bucket name: ")
	bucketName, _ := reader.ReadString('\n')
	bucketName = strings.TrimSpace(bucketName)

	if !utils.InputChecker(bucketName) {
		fmt.Println("Bucket name cannot be empty.")
		return
	}

	// Get current status
	status, err := s3model.GetBucketVersioningStatusModel(bucketName)
	if err != nil {
		fmt.Println("Error checking versioning:", err.Error())
		return
	}

	if status == "" {
		status = "Not Enabled"
	}

	fmt.Println("Current Versioning Status:", status)

	var newStatus string
	if status == "Enabled" {
		fmt.Print("Do you want to Suspend versioning? (y/n): ")
		choice, _ := reader.ReadString('\n')
		choice = strings.TrimSpace(choice)
		if choice == "y" {
			newStatus = "Suspended"
		}
	} else {
		fmt.Print("Do you want to Enable versioning? (y/n): ")
		choice, _ := reader.ReadString('\n')
		choice = strings.TrimSpace(choice)

		if choice == "y" {
			newStatus = "Enabled"
		}
	}

	if newStatus == "" {
		fmt.Println("No changes made.")
		return
	}

	// Apply change
	err = s3model.SetBucketVersioningModel(bucketName, newStatus)
	if err != nil {
		errMsg := err.Error()
		if strings.Contains(errMsg, "MfaDelete") || strings.Contains(errMsg, "MFA") {
			fmt.Println(utils.Red + "\n Cannot change versioning: MFA Delete is enabled on this bucket." + utils.Reset)
			fmt.Println(utils.Yellow + "Please disable MFA Delete first before changing versioning status." + utils.Reset)
		} else {
			fmt.Println(utils.Red + "Error setting versioning: " + errMsg + utils.Reset)
		}
		return
	}

	fmt.Println(utils.Green + "✓ Bucket versioning updated to: " + newStatus + utils.Reset)
}
