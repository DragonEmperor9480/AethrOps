package constants

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
