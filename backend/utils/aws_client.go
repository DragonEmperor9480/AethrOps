package utils

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"sync"

	"github.com/DragonEmperor9480/AethrOps/db_service"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
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
	awsConfig    aws.Config // Store config for creating region-specific clients

	// Client cache for region-specific clients
	ec2ClientCache sync.Map // map[string]*ec2.Client
)

// InitAWSClients initializes AWS SDK clients from the active database account
func InitAWSClients() error {
	// 1. Check if DB is initialized
	if db_service.DB == nil {
		log.Println("Database not initialized, loading AWS config from files...")
		return initAWSClientsFromFile()
	}

	// 2. Fetch active AWS account
	var activeAccount db_service.AWSAccount
	err := db_service.DB.Where("is_active = ?", true).First(&activeAccount).Error
	if err != nil {
		log.Println("No active database AWS account found, falling back to file-based config...")
		return initAWSClientsFromFile()
	}

	// 3. Decrypt the secret access key
	decryptedSecret, err := db_service.Decrypt(activeAccount.SecretAccessKey)
	if err != nil {
		return fmt.Errorf("failed to decrypt AWS secret key: %w", err)
	}

	// Dynamic min helper
	minVal := func(a, b int) int {
		if a < b {
			return a
		}
		return b
	}
	log.Printf("Initializing AWS clients for profile: %s (Region: %s, AccessKey: %s...)",
		activeAccount.ProfileName, activeAccount.Region, activeAccount.AccessKeyID[:minVal(5, len(activeAccount.AccessKeyID))])

	// 4. Create in-memory config using the decrypted static credentials
	ctx := context.TODO()
	cfg, err := config.LoadDefaultConfig(ctx,
		config.WithRegion(activeAccount.Region),
		config.WithCredentialsProvider(credentials.NewStaticCredentialsProvider(
			activeAccount.AccessKeyID,
			decryptedSecret,
			"",
		)),
	)
	if err != nil {
		return fmt.Errorf("failed to load AWS default config: %w", err)
	}

	// Store config for creating region-specific clients
	awsConfig = cfg

	EC2Client = ec2.NewFromConfig(cfg)
	IAMClient = iam.NewFromConfig(cfg)
	LogsClient = cloudwatchlogs.NewFromConfig(cfg)
	LambdaClient = lambda.NewFromConfig(cfg)
	S3Client = s3.NewFromConfig(cfg)
	STSClient = sts.NewFromConfig(cfg)
	return nil
}

// initAWSClientsFromFile is a legacy fallback to load AWS credentials from ~/.aethrops/credentials and config files
func initAWSClientsFromFile() error {
	credPath := getAethrOpsCredentialsPath()
	configPath := getAethrOpsConfigPath()

	log.Printf("Loading AWS credentials from: %s", credPath)
	log.Printf("Loading AWS config from: %s", configPath)

	// Force AWS SDK to use our custom paths by setting environment variables
	if err := os.Setenv("AWS_SHARED_CREDENTIALS_FILE", credPath); err != nil {
		return fmt.Errorf("failed to set credentials path: %w", err)
	}
	if err := os.Setenv("AWS_CONFIG_FILE", configPath); err != nil {
		return fmt.Errorf("failed to set config path: %w", err)
	}

	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		return err
	}

	// Store config for creating region-specific clients
	awsConfig = cfg

	EC2Client = ec2.NewFromConfig(cfg)
	IAMClient = iam.NewFromConfig(cfg)
	LogsClient = cloudwatchlogs.NewFromConfig(cfg)
	LambdaClient = lambda.NewFromConfig(cfg)
	S3Client = s3.NewFromConfig(cfg)
	STSClient = sts.NewFromConfig(cfg)
	return nil
}

// getAethrOpsCredentialsPath returns the path to .aethrops/credentials
func getAethrOpsCredentialsPath() string {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
	return filepath.Join(homeDir, ".aethrops", "credentials")
}

// getAethrOpsConfigPath returns the path to .aethrops/config
func getAethrOpsConfigPath() string {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
	return filepath.Join(homeDir, ".aethrops", "config")
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

// GetEC2ClientForRegion creates or returns a cached EC2 client for a specific region
func GetEC2ClientForRegion(region string) (*ec2.Client, error) {
	if awsConfig.Region == "" {
		return nil, fmt.Errorf("AWS config not initialized")
	}

	// Check cache first
	if cached, ok := ec2ClientCache.Load(region); ok {
		return cached.(*ec2.Client), nil
	}

	// Clone the existing config and change the region
	cfg := awsConfig
	cfg.Region = region

	client := ec2.NewFromConfig(cfg)

	// Store in cache
	ec2ClientCache.Store(region, client)

	return client, nil
}

// GetAllAWSRegions returns list of all AWS regions
func GetAllAWSRegions() ([]string, error) {
	ctx := context.TODO()

	// Use the default EC2 client to describe regions
	result, err := EC2Client.DescribeRegions(ctx, &ec2.DescribeRegionsInput{
		AllRegions: aws.Bool(true), // Include opt-in regions
	})
	if err != nil {
		return nil, err
	}

	regions := make([]string, 0, len(result.Regions))
	for _, region := range result.Regions {
		regions = append(regions, aws.ToString(region.RegionName))
	}

	return regions, nil
}

// GetCurrentRegion returns the configured default region
func GetCurrentRegion() string {
	return awsConfig.Region
}
