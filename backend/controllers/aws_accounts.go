package controllers

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"strconv"
	"strings"
	"sync"

	"github.com/DragonEmperor9480/AethrOps/db_service"
	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/sts"
	"github.com/gorilla/mux"
	"gorm.io/gorm"
)

// accountMu serializes changes to the active account so the database flag and
// the installed AWS clients always move together.
var accountMu sync.Mutex

// GetAuthStatus checks the current AWS account status in the database
func GetAuthStatus(w http.ResponseWriter, r *http.Request) {
	if db_service.DB == nil {
		respondJSON(w, http.StatusOK, map[string]interface{}{
			"status":  "no_accounts",
			"message": "Database not initialized",
		})
		return
	}

	var activeAccount db_service.AWSAccount
	err := db_service.DB.Where("is_active = ?", true).First(&activeAccount).Error
	if err == nil {
		// Active account exists, mask the access key ID
		maskedKey := maskAccessKey(activeAccount.AccessKeyID)
		respondJSON(w, http.StatusOK, map[string]interface{}{
			"status": "authenticated",
			"active_account": map[string]interface{}{
				"id":            activeAccount.ID,
				"profile_name":  activeAccount.ProfileName,
				"access_key_id": maskedKey,
				"region":        activeAccount.Region,
				"output":        activeAccount.Output,
			},
		})
		return
	}

	// No active account, check if any accounts exist in database
	var count int64
	db_service.DB.Model(&db_service.AWSAccount{}).Count(&count)
	if count > 0 {
		respondJSON(w, http.StatusOK, map[string]interface{}{
			"status":  "select_account",
			"message": "Select an account to log in",
		})
	} else {
		respondJSON(w, http.StatusOK, map[string]interface{}{
			"status":  "no_accounts",
			"message": "No accounts configured",
		})
	}
}

// ListAccounts lists all configured AWS profiles with masked keys
func ListAccounts(w http.ResponseWriter, r *http.Request) {
	var accounts []db_service.AWSAccount
	if err := db_service.DB.Find(&accounts).Error; err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to retrieve accounts")
		return
	}

	var responseList []map[string]interface{}
	for _, acc := range accounts {
		responseList = append(responseList, map[string]interface{}{
			"id":            acc.ID,
			"profile_name":  acc.ProfileName,
			"access_key_id": maskAccessKey(acc.AccessKeyID),
			"region":        acc.Region,
			"output":        acc.Output,
			"is_active":     acc.IsActive,
		})
	}

	respondJSON(w, http.StatusOK, responseList)
}

// CreateAccount adds a new AWS profile to the database
func CreateAccount(w http.ResponseWriter, r *http.Request) {
	var req struct {
		ProfileName     string `json:"profile_name"`
		AccessKeyID     string `json:"access_key_id"`
		SecretAccessKey string `json:"secret_access_key"`
		Region          string `json:"region"`
		Output          string `json:"output"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	// Validate inputs
	req.ProfileName = strings.TrimSpace(req.ProfileName)
	req.AccessKeyID = strings.TrimSpace(req.AccessKeyID)
	req.SecretAccessKey = strings.TrimSpace(req.SecretAccessKey)
	req.Region = strings.TrimSpace(req.Region)
	req.Output = strings.TrimSpace(req.Output)

	if req.ProfileName == "" || req.AccessKeyID == "" || req.SecretAccessKey == "" || req.Region == "" {
		respondError(w, http.StatusBadRequest, "All fields except output are required")
		return
	}

	if req.Output == "" {
		req.Output = "json"
	}

	// Check if profile name already exists
	var existing db_service.AWSAccount
	if err := db_service.DB.Where("profile_name = ?", req.ProfileName).First(&existing).Error; err == nil {
		respondError(w, http.StatusBadRequest, "An account profile with this name already exists")
		return
	}

	// Validate credentials by calling sts.GetCallerIdentity in-memory
	ctx := context.TODO()
	cfg, err := config.LoadDefaultConfig(ctx,
		config.WithRegion(req.Region),
		config.WithCredentialsProvider(credentials.NewStaticCredentialsProvider(
			req.AccessKeyID,
			req.SecretAccessKey,
			"",
		)),
	)
	if err != nil {
		respondError(w, http.StatusBadRequest, "Failed to load validation config: "+err.Error())
		return
	}

	stsClient := sts.NewFromConfig(cfg)
	_, err = stsClient.GetCallerIdentity(ctx, &sts.GetCallerIdentityInput{})
	if err != nil {
		respondError(w, http.StatusBadRequest, "Invalid AWS credentials: "+err.Error())
		return
	}

	// Encrypt secret key
	encSecret, err := db_service.Encrypt(req.SecretAccessKey)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to encrypt credentials")
		return
	}

	accountMu.Lock()
	defer accountMu.Unlock()

	// The first account becomes the active one
	var count int64
	if err := db_service.DB.Model(&db_service.AWSAccount{}).Count(&count).Error; err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to read accounts: "+err.Error())
		return
	}
	isActive := count == 0

	account := db_service.AWSAccount{
		ProfileName:     req.ProfileName,
		AccessKeyID:     req.AccessKeyID,
		SecretAccessKey: encSecret,
		Region:          req.Region,
		Output:          req.Output,
		IsActive:        isActive,
	}

	err = db_service.DB.Transaction(func(tx *gorm.DB) error {
		if isActive {
			if err := tx.Model(&db_service.AWSAccount{}).Where("is_active = ?", true).Update("is_active", false).Error; err != nil {
				return err
			}
		}
		return tx.Create(&account).Error
	})
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to save account to database: "+err.Error())
		return
	}

	// The credentials were just validated with this config, so use it directly
	if isActive {
		utils.UseAWSConfig(cfg)
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"message": "AWS account profile created successfully",
		"account": map[string]interface{}{
			"id":           account.ID,
			"profile_name": account.ProfileName,
			"is_active":    account.IsActive,
		},
	})
}

// ActivateAccount marks an AWS account profile as active
func ActivateAccount(w http.ResponseWriter, r *http.Request) {
	var req struct {
		ID uint `json:"id"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	accountMu.Lock()
	defer accountMu.Unlock()

	// Find the account
	var target db_service.AWSAccount
	if err := db_service.DB.First(&target, req.ID).Error; err != nil {
		respondError(w, http.StatusNotFound, "Account not found")
		return
	}

	// Build the clients first: if the account can't be used, nothing changes
	cfg, err := utils.LoadAccountConfig(target)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to initialize AWS clients for activated profile: "+err.Error())
		return
	}

	if err := setActiveAccount(db_service.DB, target.ID); err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to activate account: "+err.Error())
		return
	}
	utils.UseAWSConfig(cfg)

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"message": "Account profile activated successfully",
		"active_account": map[string]interface{}{
			"id":           target.ID,
			"profile_name": target.ProfileName,
			"region":       target.Region,
		},
	})
}

// DeleteAccount removes an AWS account from the database
func DeleteAccount(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	idStr := vars["id"]
	id, err := strconv.ParseUint(idStr, 10, 32)
	if err != nil {
		respondError(w, http.StatusBadRequest, "Invalid account ID")
		return
	}

	accountMu.Lock()
	defer accountMu.Unlock()

	// Find account
	var target db_service.AWSAccount
	if err := db_service.DB.First(&target, uint(id)).Error; err != nil {
		respondError(w, http.StatusNotFound, "Account not found")
		return
	}

	wasActive := target.IsActive

	// When deleting the active account, promote another one, but only if its
	// clients can be built. Otherwise no account is left active and the user
	// is asked to pick one.
	var next *db_service.AWSAccount
	var nextCfg aws.Config
	if wasActive {
		var candidate db_service.AWSAccount
		if err := db_service.DB.Where("id <> ?", target.ID).First(&candidate).Error; err == nil {
			if cfg, err := utils.LoadAccountConfig(candidate); err == nil {
				next, nextCfg = &candidate, cfg
			} else {
				log.Printf("Not activating account %q after delete: %v", candidate.ProfileName, err)
			}
		}
	}

	// Delete (Hard delete to avoid unique constraint violations on re-creation)
	err = db_service.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Unscoped().Delete(&target).Error; err != nil {
			return err
		}
		if next != nil {
			return setActiveAccount(tx, next.ID)
		}
		return nil
	})
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to delete account")
		return
	}

	if wasActive {
		if next != nil {
			utils.UseAWSConfig(nextCfg)
		} else {
			utils.ResetAWSClients()
		}
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"message": "Account deleted successfully",
	})
}

// setActiveAccount makes id the only active account, atomically.
func setActiveAccount(db *gorm.DB, id uint) error {
	return db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Model(&db_service.AWSAccount{}).Where("is_active = ? AND id <> ?", true, id).Update("is_active", false).Error; err != nil {
			return err
		}
		res := tx.Model(&db_service.AWSAccount{}).Where("id = ?", id).Update("is_active", true)
		if res.Error != nil {
			return res.Error
		}
		if res.RowsAffected == 0 {
			return gorm.ErrRecordNotFound
		}
		return nil
	})
}

// Helper: Mask Access Key ID
func maskAccessKey(key string) string {
	if len(key) <= 8 {
		return "****"
	}
	return key[:5] + "..." + key[len(key)-4:]
}
