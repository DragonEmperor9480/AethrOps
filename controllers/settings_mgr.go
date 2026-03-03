package controllers

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	"github.com/DragonEmperor9480/AethrOps/service"
	"github.com/DragonEmperor9480/AethrOps/utils"
)

func Settings_mgr() {
	reader := bufio.NewReader(os.Stdin)

	for {
		fmt.Println()
		fmt.Println(utils.Bold + utils.Cyan + "Settings Menu:" + utils.Reset)
		fmt.Println("────────────────────────────────────")
		fmt.Println(utils.Bold + utils.Green + "MFA Device Configuration:" + utils.Reset)
		fmt.Println(utils.Bold + utils.Blue + "[1]" + utils.Reset + " View Current MFA Device")
		fmt.Println(utils.Bold + utils.Blue + "[2]" + utils.Reset + " Update MFA Device")
		fmt.Println("────────────────────────────────────")
		fmt.Println(utils.Bold + utils.Red + "[0]" + utils.Reset + " Back to Main Menu")
		fmt.Println("────────────────────────────────────")
		fmt.Print("Select option: ")

		input, _ := reader.ReadString('\n')
		input = strings.TrimSpace(input)

		switch input {
		case "1":
			viewMFADevice()
		case "2":
			updateMFADevice(reader)
		case "0":
			return
		default:
			fmt.Println(utils.Red + "Invalid option. Please try again." + utils.Reset)
		}

		fmt.Print("\nPress Enter to continue...")
		reader.ReadString('\n')
	}
}

func viewMFADevice() {
	fmt.Println()
	fmt.Println(utils.Bold + utils.Cyan + "Current MFA Device:" + utils.Reset)
	fmt.Println("────────────────────────────────────")

	device, err := service.LoadMFADevice()
	if err != nil {
		fmt.Println(utils.Yellow + "No MFA device configured." + utils.Reset)
		fmt.Println(utils.Cyan + "Use option 2 to add your MFA device." + utils.Reset)
		return
	}

	fmt.Printf("%sDevice Name:%s %s\n", utils.Bold, utils.Reset, device.DeviceName)
	fmt.Printf("%sDevice ARN:%s  %s\n", utils.Bold, utils.Reset, device.DeviceARN)
}

func updateMFADevice(reader *bufio.Reader) {
	fmt.Println()
	fmt.Println(utils.Bold + utils.Cyan + "Update MFA Device:" + utils.Reset)
	fmt.Println("────────────────────────────────────")

	// Check if device exists
	existingDevice, _ := service.LoadMFADevice()
	if existingDevice != nil {
		fmt.Printf("%sCurrent Device:%s %s\n", utils.Bold, utils.Reset, existingDevice.DeviceName)
		fmt.Printf("%sCurrent ARN:%s    %s\n\n", utils.Bold, utils.Reset, existingDevice.DeviceARN)
	}

	fmt.Print("Device Name (e.g., 'My Phone', 'YubiKey'): ")
	deviceName, _ := reader.ReadString('\n')
	deviceName = strings.TrimSpace(deviceName)

	if deviceName == "" {
		fmt.Println(utils.Red + "Device name cannot be empty." + utils.Reset)
		return
	}

	fmt.Print("Device ARN (e.g., arn:aws:iam::123456789012:mfa/user): ")
	deviceARN, _ := reader.ReadString('\n')
	deviceARN = strings.TrimSpace(deviceARN)

	if deviceARN == "" {
		fmt.Println(utils.Red + "Device ARN cannot be empty." + utils.Reset)
		return
	}

	err := service.SaveMFADevice(deviceName, deviceARN)
	if err != nil {
		fmt.Println(utils.Red + "Error saving MFA device: " + err.Error() + utils.Reset)
		return
	}

	fmt.Println(utils.Green + "MFA device updated successfully!" + utils.Reset)
}
