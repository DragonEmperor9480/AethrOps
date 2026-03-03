package s3

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	s3model "github.com/DragonEmperor9480/AethrOps/models/s3"
	views "github.com/DragonEmperor9480/AethrOps/views/s3"
)

func S3ListBucketObjectsController() {
	ListS3Buckets()
	reader := bufio.NewReader(os.Stdin)
	fmt.Print("Enter the bucket name you want to list objects from: ")
	bucketName, _ := reader.ReadString('\n')
	bucketName = strings.TrimSpace(bucketName)

	if bucketName == "" {
		fmt.Println("Error: Please enter a valid bucket name.")
		return
	}

	output, err := s3model.S3ListBucketObjects(bucketName)
	if err != nil {
		views.PrintError(err.Error())
		return
	}

	// Parse output back to lines for view
	lines := strings.Split(output, "\n")
	views.PrintS3Objects(lines)
}
