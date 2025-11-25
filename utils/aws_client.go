package utils

import (
	"context"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/cloudwatchlogs"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	"github.com/aws/aws-sdk-go-v2/service/iam"
	"github.com/aws/aws-sdk-go-v2/service/lambda"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/sts"
)

var (
	EC2Client    *ec2.Client
	IAMClient    *iam.Client
	LogsClient   *cloudwatchlogs.Client
	LambdaClient *lambda.Client
	S3Client     *s3.Client
	STSClient    *sts.Client
)

// InitAWSClients initializes AWS SDK clients
func InitAWSClients() error {
	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		return err
	}

	EC2Client = ec2.NewFromConfig(cfg)
	IAMClient = iam.NewFromConfig(cfg)
	LogsClient = cloudwatchlogs.NewFromConfig(cfg)
	LambdaClient = lambda.NewFromConfig(cfg)
	S3Client = s3.NewFromConfig(cfg)
	STSClient = sts.NewFromConfig(cfg)
	return nil
}

// GetEC2Client returns the EC2 client
func GetEC2Client() *ec2.Client {
	return EC2Client
}

// GetIAMClient returns the IAM client
func GetIAMClient() *iam.Client {
	return IAMClient
}

// GetLogsClient returns the CloudWatch Logs client
func GetLogsClient() *cloudwatchlogs.Client {
	return LogsClient
}

// GetLambdaClient returns the Lambda client
func GetLambdaClient() *lambda.Client {
	return LambdaClient
}

// GetS3Client returns the S3 client
func GetS3Client() *s3.Client {
	return S3Client
}

// GetSTSClient returns the STS client
func GetSTSClient() *sts.Client {
	return STSClient
}

// GetAWSAccountID returns the AWS account ID
func GetAWSAccountID() (string, error) {
	ctx := context.TODO()
	result, err := STSClient.GetCallerIdentity(ctx, &sts.GetCallerIdentityInput{})
	if err != nil {
		return "", err
	}
	return *result.Account, nil
}

// GetAWSAccountAlias returns the first account alias if available, otherwise empty string
func GetAWSAccountAlias() (string, error) {
	ctx := context.TODO()
	result, err := IAMClient.ListAccountAliases(ctx, &iam.ListAccountAliasesInput{})
	if err != nil {
		return "", err
	}
	if len(result.AccountAliases) > 0 {
		return result.AccountAliases[0], nil
	}
	return "", nil
}

// GetConsoleSignInURL returns the AWS console sign-in URL
// If an account alias exists, it uses the alias, otherwise uses the account ID
func GetConsoleSignInURL() (string, error) {
	alias, err := GetAWSAccountAlias()
	if err != nil {
		return "", err
	}

	if alias != "" {
		return "https://" + alias + ".signin.aws.amazon.com/console", nil
	}

	accountID, err := GetAWSAccountID()
	if err != nil {
		return "", err
	}

	return "https://" + accountID + ".signin.aws.amazon.com/console", nil
}
