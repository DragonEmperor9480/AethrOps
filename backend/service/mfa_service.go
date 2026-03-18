package service

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

type MFADevice struct {
	DeviceName string `json:"device_name"`
	DeviceARN  string `json:"device_arn"`
}

// LoadMFADevice loads MFA device configuration from file
func LoadMFADevice() (*MFADevice, error) {
	configDir, err := getConfigDirectory()
	if err != nil {
		return nil, fmt.Errorf("failed to get config directory: %v", err)
	}

	mfaConfigFile := filepath.Join(configDir, "mfa_device.json")

	// Check if file exists
	if _, err := os.Stat(mfaConfigFile); os.IsNotExist(err) {
		return nil, fmt.Errorf("MFA device not configured")
	}

	// Read the file
	data, err := os.ReadFile(mfaConfigFile)
	if err != nil {
		return nil, fmt.Errorf("failed to read MFA config: %v", err)
	}

	// Parse JSON
	var device MFADevice
	if err := json.Unmarshal(data, &device); err != nil {
		return nil, fmt.Errorf("failed to parse MFA config: %v", err)
	}

	return &device, nil
}

// SaveMFADevice saves MFA device configuration to file
func SaveMFADevice(deviceName, deviceARN string) error {
	configDir, err := getConfigDirectory()
	if err != nil {
		return fmt.Errorf("failed to get config directory: %v", err)
	}

	mfaConfigFile := filepath.Join(configDir, "mfa_device.json")

	device := MFADevice{
		DeviceName: deviceName,
		DeviceARN:  deviceARN,
	}

	// Marshal to JSON
	data, err := json.MarshalIndent(device, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal MFA device: %v", err)
	}

	// Write to file
	if err := os.WriteFile(mfaConfigFile, data, 0600); err != nil {
		return fmt.Errorf("failed to write MFA config file: %v", err)
	}

	return nil
}

// DeleteMFADevice deletes the MFA device configuration file
func DeleteMFADevice() error {
	configDir, err := getConfigDirectory()
	if err != nil {
		return fmt.Errorf("failed to get config directory: %v", err)
	}

	mfaConfigFile := filepath.Join(configDir, "mfa_device.json")

	// Check if file exists
	if _, err := os.Stat(mfaConfigFile); os.IsNotExist(err) {
		return nil // Already deleted
	}

	// Delete the file
	if err := os.Remove(mfaConfigFile); err != nil {
		return fmt.Errorf("failed to delete MFA config file: %v", err)
	}

	return nil
}
