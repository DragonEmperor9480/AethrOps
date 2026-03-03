package s3

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	s3model "github.com/DragonEmperor9480/AethrOps/models/s3"
)

func DeleteS3Bucket() {
	reader := bufio.NewReader(os.Stdin)
	ListS3Buckets()
	// Ask for bucket name
	fmt.Print("Enter the S3 bucket name to delete: ")
	bucketName, _ := reader.ReadString('\n')
	bucketName = strings.TrimSpace(bucketName)

	if bucketName == "" {
		fmt.Println("Bucket name cannot be empty.")
		return
	}

	// Call model
	err := s3model.DeleteS3BucketModel(bucketName)
	if err != nil {
		fmt.Println("Error:", err.Error())
	} else {
		fmt.Println("S3 bucket deleted successfully:", bucketName)
	}
}
