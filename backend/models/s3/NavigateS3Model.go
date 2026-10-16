package s3

import (
	"context"
	"fmt"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
)

// S3Item represents a file or folder in S3
type S3Item struct {
	Key          string
	Size         int64
	LastModified string
	IsFolder     bool
}

// ListS3ItemsWithPrefix lists objects in a bucket with a specific prefix (for folder navigation)
func ListS3ItemsWithPrefix(bucketName, prefix string) ([]S3Item, error) {
	client := utils.GetS3Client()
	ctx := context.TODO()

	delimiter := "/"
	input := &s3.ListObjectsV2Input{
		Bucket:    &bucketName,
		Prefix:    &prefix,
		Delimiter: &delimiter, // This groups items by "folder"
	}

	// ListObjectsV2 returns at most 1000 keys per page; collect every page
	var commonPrefixes []types.CommonPrefix
	var contents []types.Object
	paginator := s3.NewListObjectsV2Paginator(client, input)
	for paginator.HasMorePages() {
		page, err := paginator.NextPage(ctx)
		if err != nil {
			return nil, fmt.Errorf("failed to list objects: %w", err)
		}
		commonPrefixes = append(commonPrefixes, page.CommonPrefixes...)
		contents = append(contents, page.Contents...)
	}

	items := make([]S3Item, 0, len(commonPrefixes)+len(contents))

	// Add folders (common prefixes)
	for _, commonPrefix := range commonPrefixes {
		if commonPrefix.Prefix != nil {
			items = append(items, S3Item{
				Key:      *commonPrefix.Prefix,
				IsFolder: true,
			})
		}
	}

	// Add files
	for _, obj := range contents {
		if obj.Key != nil && *obj.Key != prefix {
			size := int64(0)
			lastModified := ""

			if obj.Size != nil {
				size = *obj.Size
			}
			if obj.LastModified != nil {
				lastModified = obj.LastModified.Format("2006-01-02 15:04:05")
			}

			items = append(items, S3Item{
				Key:          *obj.Key,
				Size:         size,
				LastModified: lastModified,
				IsFolder:     false,
			})
		}
	}

	return items, nil
}
