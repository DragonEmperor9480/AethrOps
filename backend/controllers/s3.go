package controllers

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"

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

// DownloadS3Object downloads an object from S3 bucket with streaming support
func DownloadS3Object(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	bucketname := vars["bucketname"]
	objectkey := vars["objectkey"]

	// Get AWS S3 client
	client := utils.GetS3Client()
	ctx := context.TODO()

	input := &s3sdk.GetObjectInput{
		Bucket: &bucketname,
		Key:    &objectkey,
	}

	result, err := client.GetObject(ctx, input)
	if err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer result.Body.Close()

	// Get metadata to set proper content type
	if result.ContentType != nil {
		w.Header().Set("Content-Type", *result.ContentType)
	}

	// Set headers for file download
	w.Header().Set("Content-Disposition", "attachment; filename=\""+objectkey+"\"")

	// CRITICAL: Set content length for Dio progress tracking
	if result.ContentLength != nil {
		w.Header().Set("Content-Length", fmt.Sprintf("%d", *result.ContentLength))
	}

	w.WriteHeader(http.StatusOK)

	// Stream the data with maximum speed - use 1MB chunks for localhost performance
	buffer := make([]byte, 1024*1024) // 1MB chunks for maximum throughput
	for {
		n, err := result.Body.Read(buffer)
		if n > 0 {
			if _, writeErr := w.Write(buffer[:n]); writeErr != nil {
				return
			}
			// Flush to send data immediately
			if flusher, ok := w.(http.Flusher); ok {
				flusher.Flush()
			}
		}
		if err == io.EOF {
			break
		}
		if err != nil {
			return
		}
	}
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
func UploadS3Object(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	bucketname := vars["bucketname"]

	// Set headers for streaming response
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("X-Content-Type-Options", "nosniff")

	flusher, ok := w.(http.Flusher)
	if !ok {
		respondError(w, http.StatusInternalServerError, "Streaming not supported")
		return
	}

	// Limit request body size to 500MB to prevent memory exhaustion
	r.Body = http.MaxBytesReader(w, r.Body, 500<<20)

	// Parse multipart form (max 500MB)
	err := r.ParseMultipartForm(500 << 20)
	if err != nil {
		respondError(w, http.StatusBadRequest, "Failed to parse form: "+err.Error())
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		respondError(w, http.StatusBadRequest, "Failed to get file: "+err.Error())
		return
	}
	defer file.Close()

	objectKey := r.FormValue("key")
	if objectKey == "" {
		objectKey = header.Filename
	}

	fileSize := header.Size

	// Get temp directory - use app's data directory if available (for mobile)
	tempDir := os.Getenv("AETHROPS_DATA_DIR")
	if tempDir == "" {
		tempDir = os.TempDir()
	}

	// Create temp file in the appropriate directory
	tempFile, err := os.CreateTemp(tempDir, "s3upload-*-"+header.Filename)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to create temp file: "+err.Error())
		return
	}
	tempFilePath := tempFile.Name()
	defer tempFile.Close()
	defer os.Remove(tempFilePath)

	// Copy file to temp location (this is fast for localhost)
	_, err = io.Copy(tempFile, file)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to save file: "+err.Error())
		return
	}

	// Close the file before uploading
	if err := tempFile.Close(); err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to close temp file: "+err.Error())
		return
	}

	// Start the response with initial progress
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"progress": 0,
		"total":    fileSize,
	})
	flusher.Flush()

	// Upload to S3 with progress tracking
	progressSent := int64(0)
	err = s3.UploadS3ObjectWithProgress(bucketname, objectKey, tempFilePath, func(current, total int64) {
		// Send progress updates every 10% to avoid flooding while maintaining responsiveness
		if current-progressSent > total/10 || current == total {
			progressSent = current
			_, _ = w.Write([]byte("\n"))
			_ = json.NewEncoder(w).Encode(map[string]interface{}{
				"progress": current,
				"total":    total,
			})
			flusher.Flush()
		}
	})

	if err != nil {
		_, _ = w.Write([]byte("\n"))
		_ = json.NewEncoder(w).Encode(map[string]interface{}{
			"error": "Failed to upload to S3: " + err.Error(),
		})
		flusher.Flush()
		return
	}

	// Send completion
	_, _ = w.Write([]byte("\n"))
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"progress": fileSize,
		"total":    fileSize,
		"complete": true,
		"message":  "Upload successful",
	})
	flusher.Flush()
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
