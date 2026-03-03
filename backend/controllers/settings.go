package controllers

import (
	"encoding/json"
	"net/http"

	"github.com/DragonEmperor9480/AethrOps/service"
)

// GetMFADevice gets the stored MFA device
func GetMFADevice(w http.ResponseWriter, r *http.Request) {
	device, err := service.LoadMFADevice()
	if err != nil {
		respondJSON(w, http.StatusOK, map[string]interface{}{
			"configured": false,
			"message":    "No MFA device configured",
		})
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"configured":  true,
		"device_name": device.DeviceName,
		"device_arn":  device.DeviceARN,
	})
}

// SaveMFADevice saves or updates the MFA device
func SaveMFADevice(w http.ResponseWriter, r *http.Request) {
	var req struct {
		DeviceName string `json:"device_name"`
		DeviceARN  string `json:"device_arn"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	if req.DeviceName == "" || req.DeviceARN == "" {
		respondError(w, http.StatusBadRequest, "device_name and device_arn are required")
		return
	}

	err := service.SaveMFADevice(req.DeviceName, req.DeviceARN)
	if err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{"message": "MFA device saved successfully"})
}

// DeleteMFADevice deletes the MFA device configuration
func DeleteMFADevice(w http.ResponseWriter, r *http.Request) {
	err := service.DeleteMFADevice()
	if err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{"message": "MFA device deleted successfully"})
}
