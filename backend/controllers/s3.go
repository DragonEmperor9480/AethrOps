package controllers

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"github.com/DragonEmperor9480/AethrOps/models/s3"
	"github.com/DragonEmperor9480/AethrOps/service"
	"github.com/DragonEmperor9480/AethrOps/utils"
	s3sdk "github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/gorilla/mux"
)

// ListS3Buckets returns all S3 buckets
func ListS3Buckets(w http.ResponseWriter, r *http.Request) {
	output := s3.ListS3BucketsModel()
	respondJSON(w, http.StatusOK, map[string]string{"buckets": output})
}

// CreateS3Bucket creates a new S3 bucket
func CreateS3Bucket(w http.ResponseWriter, r *http.Request) {
	var req struct {
		BucketName string `json:"bucketname"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	if req.BucketName == "" {
		respondError(w, http.StatusBadRequest, "bucketname is required")
		return
	}

	err := s3.CreateS3BucketModel(req.BucketName)
	if err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{"message": "Bucket created", "bucketname": req.BucketName})
}

// DeleteS3Bucket deletes an S3 bucket
func DeleteS3Bucket(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	bucketname := vars["bucketname"]

	err := s3.DeleteS3BucketModel(bucketname)
	if err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{"message": "Bucket deleted", "bucketname": bucketname})
}

// ListS3Objects lists objects in a bucket
func ListS3Objects(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	bucketname := vars["bucketname"]

	objects, err := s3.S3ListBucketObjects(bucketname)
	if err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{"objects": objects, "bucketname": bucketname})
}

// GetBucketVersioning gets bucket versioning status
func GetBucketVersioning(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	bucketname := vars["bucketname"]

	status, err := s3.GetBucketVersioningStatusModel(bucketname)
	if err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{"bucketname": bucketname, "status": status})
}

// SetBucketVersioning sets bucket versioning status
func SetBucketVersioning(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	bucketname := vars["bucketname"]

	var req struct {
		Status string `json:"status"` // "Enabled" or "Suspended"
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	err := s3.SetBucketVersioningModel(bucketname, req.Status)
	if err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{"message": "Versioning updated", "bucketname": bucketname, "status": req.Status})
}

// GetBucketMFADelete gets MFA delete status
func GetBucketMFADelete(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	bucketname := vars["bucketname"]

	status := s3.GetBucketVersioning(bucketname)

	// Parse the status string to extract MFA delete status
	mfaDelete := "Disabled"
	if strings.Contains(status, "MFADelete: Enabled") {
		mfaDelete = "Enabled"
	}

	respondJSON(w, http.StatusOK, map[string]string{
		"bucketname": bucketname,
		"mfa_delete": mfaDelete,
	})
}

// UpdateBucketMFADelete updates MFA delete setting
func UpdateBucketMFADelete(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	bucketname := vars["bucketname"]

	var req struct {
		Status   string `json:"status"`
		MFAToken string `json:"mfa_token"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	// Validate MFA token format
	if len(req.MFAToken) != 6 {
		respondError(w, http.StatusBadRequest, "MFA token must be 6 digits")
		return
	}

	// Get MFA device ARN from service
	mfaDevice, err := service.LoadMFADevice()
	if err != nil {
		respondError(w, http.StatusBadRequest, "MFA device not configured. Please configure it in Settings.")
		return
	}

	enable := req.Status == "Enabled"

	// Update MFA delete with error handling
	err = s3.UpdateBucketMFADelete(bucketname, mfaDevice.DeviceARN, req.MFAToken, enable)
	if err != nil {
		// Check for common error types
		errMsg := err.Error()
		if strings.Contains(errMsg, "s3:PutBucketVersioning") {
			respondError(w, http.StatusForbidden, "Permission denied: Your IAM user needs 's3:PutBucketVersioning' permission to modify MFA Delete settings.")
		} else if strings.Contains(errMsg, "InvalidToken") || strings.Contains(errMsg, "InvalidMFAToken") {
			respondError(w, http.StatusBadRequest, "Invalid MFA token. Please check your code and try again.")
		} else if strings.Contains(errMsg, "AccessDenied") {
			respondError(w, http.StatusForbidden, "Access denied. Your IAM user may lack required permissions or the MFA device ARN is incorrect.")
		} else if strings.Contains(errMsg, "NoSuchBucket") {
			respondError(w, http.StatusNotFound, "Bucket not found.")
		} else {
			respondError(w, http.StatusInternalServerError, errMsg)
		}
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"message":    "MFA delete updated successfully",
		"bucketname": bucketname,
		"enabled":    enable,
	})
}

// DownloadS3Object generates a secure presigned URL for downloading an S3 object
func DownloadS3Object(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	bucketname := vars["bucketname"]
	objectkey := vars["objectkey"]

	// Get AWS S3 client
	client := utils.GetS3Client()

	// Create a PresignClient wrapper
	presignClient := s3sdk.NewPresignClient(client)

	// Check if the client requested a forced download/attachment
	download := r.URL.Query().Get("download")

	input := &s3sdk.GetObjectInput{
		Bucket: &bucketname,
		Key:    &objectkey,
	}

	if download == "true" {
		disposition := "attachment"
		input.ResponseContentDisposition = &disposition
	} else {
		contentType := detectContentType(objectkey)
		if contentType != "" {
			input.ResponseContentType = &contentType
		}
	}

	// Sign for 15 minutes
	presignedReq, err := presignClient.PresignGetObject(context.TODO(), input, func(opts *s3sdk.PresignOptions) {
		opts.Expires = 15 * time.Minute
	})
	if err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{"url": presignedReq.URL})
}

// ListS3ObjectsWithPrefix lists objects in a bucket with a prefix (for folder navigation)
func ListS3ObjectsWithPrefix(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	bucketname := vars["bucketname"]
	prefix := r.URL.Query().Get("prefix")

	items, err := s3.ListS3ItemsWithPrefix(bucketname, prefix)
	if err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"bucketname": bucketname,
		"prefix":     prefix,
		"items":      items,
	})
}

// UploadS3Object uploads a file to S3 with streaming progress
// UploadS3Object generates a secure presigned URL for uploading an S3 object (PUT request direct to S3)
func UploadS3Object(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	bucketname := vars["bucketname"]

	var req struct {
		Key string `json:"key"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "Invalid request body: "+err.Error())
		return
	}

	if req.Key == "" {
		respondError(w, http.StatusBadRequest, "key is required")
		return
	}

	// Get AWS S3 client
	client := utils.GetS3Client()

	// Create a PresignClient wrapper
	presignClient := s3sdk.NewPresignClient(client)

	input := &s3sdk.PutObjectInput{
		Bucket: &bucketname,
		Key:    &req.Key,
	}

	// Sign for 15 minutes
	presignedReq, err := presignClient.PresignPutObject(context.TODO(), input, func(opts *s3sdk.PresignOptions) {
		opts.Expires = 15 * time.Minute
	})
	if err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{"url": presignedReq.URL})
}

// DeleteS3Object deletes an object from S3
func DeleteS3Object(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	bucketname := vars["bucketname"]
	objectkey := vars["objectkey"]

	err := s3.DeleteS3Object(bucketname, objectkey)
	if err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{
		"message":    "Object deleted successfully",
		"bucketname": bucketname,
		"key":        objectkey,
	})
}

// CreateS3Folder creates a folder (empty object with / suffix) in S3
func CreateS3Folder(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	bucketname := vars["bucketname"]

	var req struct {
		FolderPath string `json:"folder_path"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	if req.FolderPath == "" {
		respondError(w, http.StatusBadRequest, "folder_path is required")
		return
	}

	err := s3.CreateS3Folder(bucketname, req.FolderPath)
	if err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{
		"message":     "Folder created successfully",
		"bucketname":  bucketname,
		"folder_path": req.FolderPath,
	})
}

// detectContentType returns the appropriate MIME type based on the file extension
func detectContentType(key string) string {
	idx := strings.LastIndex(key, ".")
	if idx == -1 || idx == len(key)-1 {
		return ""
	}
	ext := strings.ToLower(key[idx:])

	switch ext {
	case ".mp4":
		return "video/mp4"
	case ".mkv":
		return "video/x-matroska"
	case ".avi":
		return "video/x-msvideo"
	case ".mov":
		return "video/quicktime"
	case ".webm":
		return "video/webm"
	case ".mp3":
		return "audio/mpeg"
	case ".wav":
		return "audio/wav"
	case ".ogg":
		return "audio/ogg"
	case ".pdf":
		return "application/pdf"
	case ".png":
		return "image/png"
	case ".jpg", ".jpeg":
		return "image/jpeg"
	case ".gif":
		return "image/gif"
	case ".webp":
		return "image/webp"
	case ".txt", ".log":
		return "text/plain; charset=utf-8"
	case ".html":
		return "text/html; charset=utf-8"
	case ".json":
		return "application/json; charset=utf-8"
	default:
		return ""
	}
}
