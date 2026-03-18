package db_service

import "gorm.io/gorm"

// UserCredential stores IAM user credentials
type UserCredential struct {
	gorm.Model
	Username string `gorm:"uniqueIndex;not null"`
	Password string // Encrypted
}
