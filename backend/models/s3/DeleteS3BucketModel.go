package s3

import (
	"context"
	"fmt"

	"github.com/DragonEmperor9480/AethrOps/utils"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
)

// DeleteS3BucketModel empties the bucket (all objects, versions and delete markers)
// and then deletes it.
func DeleteS3BucketModel(bucketName string) error {
	client := utils.GetS3Client()
	ctx := context.TODO()

	// Delete current objects, one page (max 1000 keys, the DeleteObjects limit) at a time
	objects := s3.NewListObjectsV2Paginator(client, &s3.ListObjectsV2Input{
		Bucket: &bucketName,
	})
	for objects.HasMorePages() {
		page, err := objects.NextPage(ctx)
		if err != nil {
			return fmt.Errorf("failed to list objects: %w", err)
		}

		toDelete := make([]types.ObjectIdentifier, 0, len(page.Contents))
		for _, obj := range page.Contents {
			toDelete = append(toDelete, types.ObjectIdentifier{Key: obj.Key})
		}
		if err := deleteObjectBatch(ctx, client, bucketName, toDelete); err != nil {
			return fmt.Errorf("failed to empty bucket: %w", err)
		}
	}

	// Delete every version and delete marker (versioned or previously versioned buckets)
	versions := s3.NewListObjectVersionsPaginator(client, &s3.ListObjectVersionsInput{
		Bucket: &bucketName,
	})
	for versions.HasMorePages() {
		page, err := versions.NextPage(ctx)
		if err != nil {
			return fmt.Errorf("failed to list object versions: %w", err)
		}

		toDelete := make([]types.ObjectIdentifier, 0, len(page.Versions)+len(page.DeleteMarkers))
		for _, v := range page.Versions {
			toDelete = append(toDelete, types.ObjectIdentifier{Key: v.Key, VersionId: v.VersionId})
		}
		for _, m := range page.DeleteMarkers {
			toDelete = append(toDelete, types.ObjectIdentifier{Key: m.Key, VersionId: m.VersionId})
		}
		if err := deleteObjectBatch(ctx, client, bucketName, toDelete); err != nil {
			return fmt.Errorf("failed to delete versions: %w", err)
		}
	}

	_, err := client.DeleteBucket(ctx, &s3.DeleteBucketInput{
		Bucket: &bucketName,
	})
	if err != nil {
		return fmt.Errorf("failed to delete bucket: %w", err)
	}

	return nil
}

// deleteObjectBatch deletes up to 1000 objects and fails if S3 reports any per-key error.
func deleteObjectBatch(ctx context.Context, client *s3.Client, bucketName string, ids []types.ObjectIdentifier) error {
	if len(ids) == 0 {
		return nil
	}

	out, err := client.DeleteObjects(ctx, &s3.DeleteObjectsInput{
		Bucket: &bucketName,
		Delete: &types.Delete{Objects: ids, Quiet: aws.Bool(true)},
	})
	if err != nil {
		return err
	}
	if len(out.Errors) > 0 {
		first := out.Errors[0]
		return fmt.Errorf("%d object(s) could not be deleted, e.g. %s: %s",
			len(out.Errors), aws.ToString(first.Key), aws.ToString(first.Message))
	}
	return nil
}
