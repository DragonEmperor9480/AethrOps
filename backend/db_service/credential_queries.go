package db_service

// SaveUserCredential saves or updates a user credential in the database
func SaveUserCredential(username, password string) error {
	// Encrypt password
	encPassword, err := Encrypt(password)
	if err != nil {
		return err
	}

	credential := UserCredential{
		Username: username,
		Password: encPassword,
	}

	// Upsert (update if exists, insert if not)
	result := DB.Where("username = ?", username).Assign(credential).FirstOrCreate(&credential)
	return result.Error
}

// UpdateUserPassword updates the password for a user
func UpdateUserPassword(username, newPassword string) error {
	encPassword, err := Encrypt(newPassword)
	if err != nil {
		return err
	}

	result := DB.Model(&UserCredential{}).Where("username = ?", username).Update("password", encPassword)
	return result.Error
}
