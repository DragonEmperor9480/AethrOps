package constants

// Local API listen address. Only loopback; the Flutter app talks to it over HTTP.
const BackendPort = "9480"
const BackendAddress = "127.0.0.1:" + BackendPort

// Environment variable the desktop app uses to pass the per-launch API token.
const AuthTokenEnv = "AETHROPS_AUTH_TOKEN"

const IamUsersFetchedSuccessfully = "IAM User(s) fetched sucessfully"
const BatchUserCreationCompleted = "Batch user creation completed"

const IAMGroupCreatedSuccessfully = "IAM Group created sucessfully"
const IAMGroupsFetchedSuccessfully = "IAM Group(s) fetched sucessfully"

const (
	UserAlreadyExists  = 1
	UserCreationError  = 2
	UserCreatedSuccess = 3
)

// Status codes for SetInitialUserPasswordModel
const (
	PasswordUserNotFound    = 1
	PasswordPolicyViolation = 2
	PasswordAlreadyExists   = 3
	PasswordCreationError   = 4
	PasswordCreatedSuccess  = 5
)

// Status codes for CreateIAMGroup
const (
	GroupAlreadyExists  = 1
	GroupCreationError  = 2
	GroupCreatedSuccess = 3
)
