package routes

import (
	api "github.com/DragonEmperor9480/AethrOps/backend/controllers"
	"github.com/gin-gonic/gin"
	"github.com/gorilla/mux"
)

// RegisterRoutes registers all API routes on the provided mux router
func RegisterRoutes(r *mux.Router) {
	// IAM Users
	r.HandleFunc("/api/iam/caller-identity", api.GetCallerIdentity).Methods("GET")
	r.HandleFunc("/api/iam/users", api.ListIAMUsers).Methods("GET")
	r.HandleFunc("/api/iam/users", api.CreateIAMUser).Methods("POST")
	r.HandleFunc("/api/iam/users/batch", api.CreateMultipleIAMUsers).Methods("POST")
	r.HandleFunc("/api/iam/users/batch/dependencies", api.CheckMultipleUserDependencies).Methods("POST")
	r.HandleFunc("/api/iam/users/batch/delete", api.DeleteMultipleIAMUsers).Methods("POST")
	r.HandleFunc("/api/iam/users/{username}/dependencies", api.CheckUserDependencies).Methods("GET")
	r.HandleFunc("/api/iam/users/{username}", api.DeleteIAMUser).Methods("DELETE")
	r.HandleFunc("/api/iam/users/{username}/password", api.SetUserPassword).Methods("POST")
	r.HandleFunc("/api/iam/users/{username}/password", api.UpdateUserPassword).Methods("PUT")
	r.HandleFunc("/api/iam/users/{username}/access-keys", api.CreateAccessKey).Methods("POST")
	r.HandleFunc("/api/iam/users/{username}/access-keys", api.ListAccessKeys).Methods("GET")
	r.HandleFunc("/api/iam/users/{username}/groups", api.ListUserGroups).Methods("GET")
	r.HandleFunc("/api/iam/users/{username}/policies", api.AttachUserPolicy).Methods("POST")
	r.HandleFunc("/api/iam/users/{username}/policies/sync", api.SyncUserPolicies).Methods("POST")
	r.HandleFunc("/api/iam/users/policies/batch", api.AttachMultipleUserPolicies).Methods("POST")
	r.HandleFunc("/api/iam/users/send-credentials", api.SendUserCredentialsEmail).Methods("POST")

	// IAM Groups
	r.HandleFunc("/api/iam/groups", api.ListIAMGroups).Methods("GET")
	r.HandleFunc("/api/iam/groups", api.CreateIAMGroup).Methods("POST")
	r.HandleFunc("/api/iam/groups/{groupname}", api.DeleteIAMGroup).Methods("DELETE")
	r.HandleFunc("/api/iam/groups/{groupname}/dependencies", api.CheckGroupDependencies).Methods("GET")
	r.HandleFunc("/api/iam/groups/{groupname}/users", api.ListUsersInGroup).Methods("GET")
	r.HandleFunc("/api/iam/groups/{groupname}/users", api.AddUserToGroup).Methods("POST")
	r.HandleFunc("/api/iam/groups/{groupname}/users/{username}", api.RemoveUserFromGroup).Methods("DELETE")
	r.HandleFunc("/api/iam/groups/{groupname}/policies", api.ListGroupPolicies).Methods("GET")
	r.HandleFunc("/api/iam/groups/{groupname}/policies", api.AttachGroupPolicy).Methods("POST")
	r.HandleFunc("/api/iam/groups/{groupname}/policies/{policy_arn:.*}", api.DetachGroupPolicy).Methods("DELETE")

	// IAM Policies
	r.HandleFunc("/api/iam/policies", api.ListIAMPolicies).Methods("GET")

	// S3 Buckets
	r.HandleFunc("/api/s3/buckets", api.ListS3Buckets).Methods("GET")
	r.HandleFunc("/api/s3/buckets", api.CreateS3Bucket).Methods("POST")
	r.HandleFunc("/api/s3/buckets/{bucketname}", api.DeleteS3Bucket).Methods("DELETE")
	r.HandleFunc("/api/s3/buckets/{bucketname}/versioning", api.GetBucketVersioning).Methods("GET")
	r.HandleFunc("/api/s3/buckets/{bucketname}/versioning", api.SetBucketVersioning).Methods("PUT")
	r.HandleFunc("/api/s3/buckets/{bucketname}/mfa-delete", api.GetBucketMFADelete).Methods("GET")
	r.HandleFunc("/api/s3/buckets/{bucketname}/mfa-delete", api.UpdateBucketMFADelete).Methods("PUT")

	// S3 Objects
	r.HandleFunc("/api/s3/buckets/{bucketname}/items", api.ListS3ObjectsWithPrefix).Methods("GET")
	r.HandleFunc("/api/s3/buckets/{bucketname}/upload", api.UploadS3Object).Methods("POST")
	r.HandleFunc("/api/s3/buckets/{bucketname}/folder", api.CreateS3Folder).Methods("POST")
	r.HandleFunc("/api/s3/buckets/{bucketname}/objects/{objectkey:.*}", api.DeleteS3Object).Methods("DELETE")
	r.HandleFunc("/api/s3/buckets/{bucketname}/objects/{objectkey:.*}", api.DownloadS3Object).Methods("GET")
	r.HandleFunc("/api/s3/buckets/{bucketname}/objects", api.ListS3Objects).Methods("GET")

	// CloudWatch
	r.HandleFunc("/api/cloudwatch/lambda/functions", api.ListLambdaFunctions).Methods("GET")
	r.HandleFunc("/api/cloudwatch/lambda/{function}/logs", api.StreamLambdaLogs).Methods("GET")
	r.HandleFunc("/api/cloudwatch/logs/download/{sessionId}", api.DownloadLogs).Methods("GET")

	// EC2 Instances (Mux routes)
	r.HandleFunc("/api/ec2/instances", api.ListEC2Instances).Methods("GET")
	r.HandleFunc("/api/ec2/instances/{instance_id}", api.GetEC2Instance).Methods("GET")
	r.HandleFunc("/api/ec2/instances/{instance_id}/start", api.StartEC2Instance).Methods("POST")
	r.HandleFunc("/api/ec2/instances/{instance_id}/stop", api.StopEC2Instance).Methods("POST")
	r.HandleFunc("/api/ec2/instances/{instance_id}/reboot", api.RebootEC2Instance).Methods("POST")
	r.HandleFunc("/api/ec2/instances/{instance_id}/terminate", api.TerminateEC2Instance).Methods("DELETE")
	r.HandleFunc("/api/ec2/instances/by-state", api.GetInstanceStateChanges).Methods("GET")

	// EC2 Launch & Configuration (Gin Router)
	gin.SetMode(gin.ReleaseMode)
	ginRouter := gin.New()
	ginRouter.POST("/api/ec2/instances", api.LaunchEC2Instance)
	ginRouter.GET("/api/ec2/security-groups", api.ListSecurityGroups)
	ginRouter.GET("/api/ec2/key-pairs", api.ListKeyPairs)
	ginRouter.GET("/api/ec2/subnets", api.ListSubnets)
	ginRouter.GET("/api/ec2/vpcs", api.ListVPCs)

	r.Handle("/api/ec2/instances", ginRouter).Methods("POST")
	r.Handle("/api/ec2/security-groups", ginRouter).Methods("GET")
	r.Handle("/api/ec2/key-pairs", ginRouter).Methods("GET")
	r.Handle("/api/ec2/subnets", ginRouter).Methods("GET")
	r.Handle("/api/ec2/vpcs", ginRouter).Methods("GET")

	// Settings
	r.HandleFunc("/api/settings/mfa", api.GetMFADevice).Methods("GET")
	r.HandleFunc("/api/settings/mfa", api.SaveMFADevice).Methods("POST")
	r.HandleFunc("/api/settings/mfa", api.DeleteMFADevice).Methods("DELETE")

	// AWS Configuration
	r.HandleFunc("/api/aws/config", api.GetAWSConfig).Methods("GET")
	r.HandleFunc("/api/aws/config", api.ConfigureAWS).Methods("POST")
	r.HandleFunc("/api/aws/config", api.DeleteAWSConfig).Methods("DELETE")
	r.HandleFunc("/api/aws/config/reload", api.ReloadAWSCredentials).Methods("POST")

	// Email Configuration
	r.HandleFunc("/api/email/config", api.GetEmailConfig).Methods("GET")
	r.HandleFunc("/api/email/config", api.SaveEmailConfig).Methods("POST")
	r.HandleFunc("/api/email/test", api.SendTestEmail).Methods("POST")
	r.HandleFunc("/api/email/config", api.DeleteEmailConfig).Methods("DELETE")

	// Version
	r.HandleFunc("/api/version", api.GetVersion).Methods("GET")
}
