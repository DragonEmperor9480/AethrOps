package controllers

import (
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/DragonEmperor9480/AethrOps/db_service"
	"github.com/DragonEmperor9480/AethrOps/utils"
)

// ConfigureAWS configures AWS credentials
func ConfigureAWS(w http.ResponseWriter, r *http.Request) {
	var req struct {
		AccessKeyID     string `json:"access_key_id"`
		SecretAccessKey string `json:"secret_access_key"`
		Region          string `json:"region"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	if req.AccessKeyID == "" || req.SecretAccessKey == "" || req.Region == "" {
		respondError(w, http.StatusBadRequest, "All fields are required")
		return
	}

	if db_service.DB == nil {
		respondError(w, http.StatusInternalServerError, "Database not initialized")
		return
	}

	// Encrypt secret key
	encSecret, err := db_service.Encrypt(req.SecretAccessKey)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to encrypt credentials: "+err.Error())
		return
	}

	var existing db_service.AWSAccount
	errExist := db_service.DB.Unscoped().Where("profile_name = ?", "default").First(&existing).Error

	// Deactivate all other accounts first if we are activating "default"
	db_service.DB.Model(&db_service.AWSAccount{}).Where("is_active = ?", true).Update("is_active", false)

	if errExist == nil {
		// Update existing default account
		existing.AccessKeyID = req.AccessKeyID
		existing.SecretAccessKey = encSecret
		existing.Region = req.Region
		existing.IsActive = true
		if err := db_service.DB.Save(&existing).Error; err != nil {
			respondError(w, http.StatusInternalServerError, "Failed to update database profile: "+err.Error())
			return
		}
	} else {
		// Create new default account
		newAcc := db_service.AWSAccount{
			ProfileName:     "default",
			AccessKeyID:     req.AccessKeyID,
			SecretAccessKey: encSecret,
			Region:          req.Region,
			IsActive:        true,
		}
		if err := db_service.DB.Create(&newAcc).Error; err != nil {
			respondError(w, http.StatusInternalServerError, "Failed to create database profile: "+err.Error())
			return
		}
	}

	// IMPORTANT: Reload AWS clients with new credentials
	if err := utils.InitAWSClients(); err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to initialize AWS clients: "+err.Error())
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{"message": "AWS credentials configured successfully"})
}

// DeleteAWSConfig deletes AWS credentials from database and clean up legacy files
func DeleteAWSConfig(w http.ResponseWriter, r *http.Request) {
	// If database is available, deactivate all active profiles and delete the "default" profile
	if db_service.DB != nil {
		db_service.DB.Unscoped().Where("profile_name = ?", "default").Delete(&db_service.AWSAccount{})
		db_service.DB.Model(&db_service.AWSAccount{}).Where("is_active = ?", true).Update("is_active", false)
	}

	// Clean up legacy files if they exist (just in case)
	if configDir, err := db_service.GetConfigDirectory(); err == nil {
		_ = os.Remove(filepath.Join(configDir, "credentials"))
		_ = os.Remove(filepath.Join(configDir, "config"))
	}

	// Reset standard AWS clients
	utils.EC2Client = nil
	utils.IAMClient = nil
	utils.LogsClient = nil
	utils.LambdaClient = nil
	utils.S3Client = nil
	utils.STSClient = nil

	respondJSON(w, http.StatusOK, map[string]string{"message": "AWS credentials deleted successfully"})
}

// GetAWSConfig gets current AWS configuration
func GetAWSConfig(w http.ResponseWriter, r *http.Request) {
	// 1. Check database first if DB is initialized
	if db_service.DB != nil {
		var activeAccount db_service.AWSAccount
		err := db_service.DB.Where("is_active = ?", true).First(&activeAccount).Error
		if err == nil {
			respondJSON(w, http.StatusOK, map[string]interface{}{
				"configured": true,
				"message":    "AWS credentials configured",
				"region":     activeAccount.Region,
			})
			return
		}
	}

	// 2. Legacy fallback: Get config directory (works for both mobile and desktop)
	configDir, err := db_service.GetConfigDirectory()
	if err != nil {
		respondJSON(w, http.StatusOK, map[string]interface{}{
			"configured": false,
			"message":    "Failed to get config directory",
		})
		return
	}

	credentialsFile := filepath.Join(configDir, "credentials")
	configFile := filepath.Join(configDir, "config")

	// Check if credentials file exists and is not empty
	credInfo, err := os.Stat(credentialsFile)
	if err != nil || credInfo.Size() == 0 {
		respondJSON(w, http.StatusOK, map[string]interface{}{
			"configured": false,
			"message":    "AWS credentials file not found",
		})
		return
	}

	// Check if config file exists
	_, err = os.Stat(configFile)
	if err != nil {
		respondJSON(w, http.StatusOK, map[string]interface{}{
			"configured": false,
			"message":    "AWS config file not found",
		})
		return
	}

	// Try to read credentials to verify they're valid format
	credContent, err := os.ReadFile(credentialsFile)
	if err != nil {
		respondJSON(w, http.StatusOK, map[string]interface{}{
			"configured": false,
			"message":    "Failed to read credentials file",
		})
		return
	}

	credStr := string(credContent)
	if !strings.Contains(credStr, "aws_access_key_id") || !strings.Contains(credStr, "aws_secret_access_key") {
		respondJSON(w, http.StatusOK, map[string]interface{}{
			"configured": false,
			"message":    "Credentials file is invalid",
		})
		return
	}

	// Read config file to get region
	configContent, err := os.ReadFile(configFile)
	if err != nil {
		respondJSON(w, http.StatusOK, map[string]interface{}{
			"configured": true,
			"message":    "AWS credentials configured",
		})
		return
	}

	// Parse region from config file
	region := ""
	configStr := string(configContent)
	for _, line := range strings.Split(configStr, "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "region") {
			parts := strings.SplitN(line, "=", 2)
			if len(parts) == 2 {
				region = strings.TrimSpace(parts[1])
				break
			}
		}
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"configured": true,
		"message":    "AWS credentials configured",
		"region":     region,
	})
}
