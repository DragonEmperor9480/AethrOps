package db_service

import "gorm.io/gorm"

// AWSAccount stores encrypted AWS credentials and region config
type AWSAccount struct {
	gorm.Model
	ProfileName     string `gorm:"uniqueIndex;not null"`
	AccessKeyID     string `gorm:"not null"`
	SecretAccessKey string `gorm:"not null"` // Encrypted
	Region          string `gorm:"not null"`
	Output          string `gorm:"default:'json'"`
	IsActive        bool   `gorm:"default:false"`
}

