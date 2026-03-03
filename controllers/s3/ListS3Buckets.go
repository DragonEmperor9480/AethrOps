package s3

import (
	"fmt"
	"strings"

	s3model "github.com/DragonEmperor9480/AethrOps/models/s3"
	views "github.com/DragonEmperor9480/AethrOps/views/s3"
)

func ListS3Buckets() {
	data := s3model.ListS3BucketsModel()
	if strings.TrimSpace(data) == "" {
		fmt.Println("No S3 buckets found.")
		return
	}
	views.RenderS3BucketsTable(data)
}
