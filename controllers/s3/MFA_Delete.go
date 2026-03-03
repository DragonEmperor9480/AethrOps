package s3

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	s3model "github.com/DragonEmperor9480/AethrOps/models/s3"
	"github.com/DragonEmperor9480/AethrOps/service"
	"github.com/DragonEmperor9480/AethrOps/utils"
)

func S3BucketMFADeleteController() {
	reader := bufio.NewReader(os.Stdin)

	ListS3Buckets()

	fmt.Print("Enter Bucket Name: ")
	bucketName, _ := reader.ReadString('\n')
	bucketName = strings.TrimSpace(bucketName)
	if bucketName == "" {
		fmt.Println(utils.Red + "Error: Please enter a valid bucket name." + utils.Reset)
		return
	}

	status := s3model.GetBucketVersioning(bucketName)

	fmt.Print("Do you want to Enable or Disable MFA Delete? (e/d): ")
	mfaChoice, _ := reader.ReadString('\n')
	mfaChoice = strings.TrimSpace(mfaChoice)

	if mfaChoice != "e" && mfaChoice != "d" {
		fmt.Println(utils.Red + "Invalid choice. Enter 'e' for enable or 'd' for disable." + utils.Reset)
		return
	}

	if (mfaChoice == "e" && strings.Contains(status, "MFADelete: Enabled")) ||
		(mfaChoice == "d" && strings.Contains(status, "MFADelete: Disabled")) {
		fmt.Println(utils.Yellow + "Already in requested state." + utils.Reset)
		return
	}

	// Get MFA device from config
	device, err := service.LoadMFADevice()
	if err != nil {
		fmt.Println(utils.Red + "Error: No MFA device configured." + utils.Reset)
		fmt.Println(utils.Yellow + "Please add an MFA device in Settings (press X from main menu)." + utils.Reset)
		return
	}

	fmt.Println()
	fmt.Printf("%sUsing MFA Device:%s %s\n", utils.Bold, utils.Reset, device.DeviceName)
	fmt.Printf("%sDevice ARN:%s       %s\n", utils.Bold, utils.Reset, device.DeviceARN)
	fmt.Println()

	securityARN := device.DeviceARN

	fmt.Print("Enter MFA code: ")
	mfaCode, _ := reader.ReadString('\n')
	mfaCode = strings.TrimSpace(mfaCode)
	if mfaCode == "" {
		fmt.Println(utils.Red + "Error: MFA code cannot be empty." + utils.Reset)
		return
	}

	// Apply change
	if mfaChoice == "e" {
		s3model.UpdateBucketMFADelete(bucketName, securityARN, mfaCode, true)
	} else {
		s3model.UpdateBucketMFADelete(bucketName, securityARN, mfaCode, false)
	}
}
