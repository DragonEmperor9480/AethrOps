package service

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/DragonEmperor9480/AethrOps/db_service"

	"gopkg.in/gomail.v2"
)

type EmailConfig struct {
	SMTPHost    string `json:"smtp_host"`
	SMTPPort    int    `json:"smtp_port"`
	SenderEmail string `json:"sender_email"`
	SenderPass  string `json:"sender_pass"`
	SenderName  string `json:"sender_name"`
}

const emailConfigFileName = "email_config.json"

// storedEmailConfig is the on-disk format. The SMTP password is encrypted with
// the per-install key.
type storedEmailConfig struct {
	SMTPHost      string `json:"smtp_host"`
	SMTPPort      int    `json:"smtp_port"`
	SenderEmail   string `json:"sender_email"`
	SenderName    string `json:"sender_name"`
	SenderPassEnc string `json:"sender_pass_enc,omitempty"`
}

// LoadEmailConfig loads email configuration from file, including the decrypted password
func LoadEmailConfig() (*EmailConfig, error) {
	emailConfigFile, err := configFilePath(emailConfigFileName)
	if err != nil {
		return nil, err
	}

	data, err := os.ReadFile(emailConfigFile)
	if os.IsNotExist(err) {
		return nil, fmt.Errorf("email configuration not found")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to read email config: %v", err)
	}

	var stored storedEmailConfig
	if err := json.Unmarshal(data, &stored); err != nil {
		return nil, fmt.Errorf("failed to parse email config: %v", err)
	}

	config := &EmailConfig{
		SMTPHost:    stored.SMTPHost,
		SMTPPort:    stored.SMTPPort,
		SenderEmail: stored.SenderEmail,
		SenderName:  stored.SenderName,
	}

	if stored.SenderPassEnc != "" {
		pass, err := db_service.Decrypt(stored.SenderPassEnc)
		if err != nil {
			return nil, fmt.Errorf("failed to decrypt email password; please save the email settings again")
		}
		config.SenderPass = pass
	}

	return config, nil
}

// SaveEmailConfig writes the email configuration with the password encrypted.
// An empty SenderPass keeps the currently saved password.
func SaveEmailConfig(config EmailConfig) error {
	if config.SenderPass == "" {
		existing, err := LoadEmailConfig()
		if err != nil || existing.SenderPass == "" {
			return fmt.Errorf("sender password is required")
		}
		config.SenderPass = existing.SenderPass
	}

	encPass, err := db_service.Encrypt(config.SenderPass)
	if err != nil {
		return fmt.Errorf("failed to encrypt email password: %v", err)
	}

	data, err := json.MarshalIndent(storedEmailConfig{
		SMTPHost:      config.SMTPHost,
		SMTPPort:      config.SMTPPort,
		SenderEmail:   config.SenderEmail,
		SenderName:    config.SenderName,
		SenderPassEnc: encPass,
	}, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal email config: %v", err)
	}

	emailConfigFile, err := configFilePath(emailConfigFileName)
	if err != nil {
		return err
	}
	if err := os.WriteFile(emailConfigFile, data, 0600); err != nil {
		return fmt.Errorf("failed to write email config file: %v", err)
	}
	return nil
}

// DeleteEmailConfig removes the saved email configuration. Returns false if none existed.
func DeleteEmailConfig() (bool, error) {
	emailConfigFile, err := configFilePath(emailConfigFileName)
	if err != nil {
		return false, err
	}
	if err := os.Remove(emailConfigFile); err != nil {
		if os.IsNotExist(err) {
			return false, nil
		}
		return false, fmt.Errorf("failed to delete email config file: %v", err)
	}
	return true, nil
}

// SendIAMCredentialsEmail sends IAM username and password to user
func SendIAMCredentialsEmail(config *EmailConfig, username, password, email, consoleURL string) error {
	if config == nil {
		return fmt.Errorf("email configuration is required")
	}

	m := gomail.NewMessage()
	m.SetHeader("From", fmt.Sprintf("%s <%s>", config.SenderName, config.SenderEmail))
	m.SetHeader("To", email)
	m.SetHeader("Subject", "🔐 Your AWS IAM Credentials")

	// Inline CSS for better email client compatibility
	htmlBody := fmt.Sprintf(`
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f5f5;">
    <table width="100%%" cellpadding="0" cellspacing="0" style="background-color: #f5f5f5; padding: 40px 20px;">
        <tr>
            <td align="center">
                <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
                    <!-- Header -->
                    <tr>
                        <td style="background: linear-gradient(135deg, #667eea 0%%, #764ba2 100%%); padding: 40px 30px; text-align: center;">
                            <h1 style="margin: 0; color: #ffffff; font-size: 32px; font-weight: 700;">🔐 AWS IAM Credentials</h1>
                            <p style="margin: 10px 0 0 0; color: rgba(255,255,255,0.9); font-size: 16px;">Your account is ready to use</p>
                        </td>
                    </tr>
                    
                    <!-- Content -->
                    <tr>
                        <td style="padding: 40px 30px;">
                            <p style="margin: 0 0 20px 0; color: #333333; font-size: 16px; line-height: 1.6;">Hello,</p>
                            <p style="margin: 0 0 30px 0; color: #333333; font-size: 16px; line-height: 1.6;">Your AWS IAM account has been created successfully. Here are your login credentials:</p>
                            
                            <!-- Credentials Box -->
                            <table width="100%%" cellpadding="0" cellspacing="0" style="background: linear-gradient(135deg, #f8f9ff 0%%, #f0f2ff 100%%); border-radius: 12px; border-left: 4px solid #667eea; margin: 30px 0;">
                                <tr>
                                    <td style="padding: 25px;">
                                        <!-- Username -->
                                        <table width="100%%" cellpadding="0" cellspacing="0" style="margin-bottom: 20px;">
                                            <tr>
                                                <td>
                                                    <p style="margin: 0 0 8px 0; color: #667eea; font-size: 13px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px;">👤 Username</p>
                                                    <div style="background-color: #ffffff; padding: 12px 16px; border-radius: 8px; border: 2px solid #e0e7ff;">
                                                        <p style="margin: 0; color: #1a1a1a; font-size: 18px; font-weight: 600; font-family: 'Courier New', monospace;">%s</p>
                                                    </div>
                                                </td>
                                            </tr>
                                        </table>
                                        
                                        <!-- Password -->
                                        <table width="100%%" cellpadding="0" cellspacing="0" style="margin-bottom: 20px;">
                                            <tr>
                                                <td>
                                                    <p style="margin: 0 0 8px 0; color: #667eea; font-size: 13px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px;">🔑 Password</p>
                                                    <div style="background-color: #ffffff; padding: 12px 16px; border-radius: 8px; border: 2px solid #e0e7ff;">
                                                        <p style="margin: 0; color: #1a1a1a; font-size: 18px; font-weight: 600; font-family: 'Courier New', monospace; word-break: break-all;">%s</p>
                                                    </div>
                                                </td>
                                            </tr>
                                        </table>
                                        
                                        <!-- Console URL -->
                                        <table width="100%%" cellpadding="0" cellspacing="0">
                                            <tr>
                                                <td>
                                                    <p style="margin: 0 0 8px 0; color: #667eea; font-size: 13px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px;">🌐 Console URL</p>
                                                    <div style="background-color: #ffffff; padding: 12px 16px; border-radius: 8px; border: 2px solid #e0e7ff;">
                                                        <a href="%s" style="margin: 0; color: #667eea; font-size: 16px; font-weight: 600; text-decoration: none; word-break: break-all;">%s</a>
                                                    </div>
                                                </td>
                                            </tr>
                                        </table>
                                    </td>
                                </tr>
                            </table>
                            
                            <p style="margin: 30px 0 20px 0; color: #333333; font-size: 16px; line-height: 1.6;">You can now log in to the AWS Console using these credentials.</p>
                            
                            <p style="margin: 30px 0 0 0; color: #333333; font-size: 16px; line-height: 1.6;">
                                Best regards,<br>
                                <strong style="color: #667eea;">%s</strong>
                            </p>
                        </td>
                    </tr>
                    
                    <!-- Footer -->
                    <tr>
                        <td style="background-color: #f8f9fa; padding: 25px 30px; text-align: center; border-top: 1px solid #e9ecef;">
                            <p style="margin: 0; color: #6c757d; font-size: 13px; line-height: 1.6;">
                                This is an automated message from AethrOps<br>
                                Please do not reply to this email
                            </p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>
`, username, password, consoleURL, consoleURL, config.SenderName)

	// Set plain text as base, then HTML as alternative (this ensures HTML is preferred)
	plainBody := fmt.Sprintf(`
AWS IAM Credentials
===================

Hello,

Your AWS IAM account has been created successfully.

Login Credentials:
------------------
Username: %s
Password: %s
Console URL: %s

You can now log in to the AWS Console using these credentials.

Best regards,
%s

---
This is an automated message from AethrOps.
Please do not reply to this email.
`, username, password, consoleURL, config.SenderName)

	m.SetBody("text/plain", plainBody)
	m.AddAlternative("text/html", htmlBody)

	d := gomail.NewDialer(config.SMTPHost, config.SMTPPort, config.SenderEmail, config.SenderPass)

	if err := d.DialAndSend(m); err != nil {
		return fmt.Errorf("failed to send email: %v", err)
	}

	return nil
}

// SendAccessKeyEmail sends AWS access key credentials to user
func SendAccessKeyEmail(config *EmailConfig, username, email, accessKey, secretKey string) error {
	if config == nil {
		return fmt.Errorf("email configuration is required")
	}

	m := gomail.NewMessage()
	m.SetHeader("From", fmt.Sprintf("%s <%s>", config.SenderName, config.SenderEmail))
	m.SetHeader("To", email)
	m.SetHeader("Subject", "🔑 Your AWS Access Keys")

	// Inline CSS for better email client compatibility
	htmlBody := fmt.Sprintf(`
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f5f5;">
    <table width="100%%" cellpadding="0" cellspacing="0" style="background-color: #f5f5f5; padding: 40px 20px;">
        <tr>
            <td align="center">
                <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
                    <!-- Header -->
                    <tr>
                        <td style="background: linear-gradient(135deg, #667eea 0%%, #764ba2 100%%); padding: 40px 30px; text-align: center;">
                            <h1 style="margin: 0; color: #ffffff; font-size: 32px; font-weight: 700;">🔑 AWS Access Keys</h1>
                            <p style="margin: 10px 0 0 0; color: rgba(255,255,255,0.9); font-size: 16px;">Your programmatic access is ready</p>
                        </td>
                    </tr>
                    
                    <!-- Content -->
                    <tr>
                        <td style="padding: 40px 30px;">
                            <p style="margin: 0 0 20px 0; color: #333333; font-size: 16px; line-height: 1.6;">Hello <strong>%s</strong>,</p>
                            <p style="margin: 0 0 30px 0; color: #333333; font-size: 16px; line-height: 1.6;">Your AWS programmatic access keys have been generated successfully. Below are your credentials:</p>
                            
                            <!-- Credentials Box -->
                            <table width="100%%" cellpadding="0" cellspacing="0" style="background: linear-gradient(135deg, #f8f9ff 0%%, #f0f2ff 100%%); border-radius: 12px; border-left: 4px solid #667eea; margin: 30px 0;">
                                <tr>
                                    <td style="padding: 25px;">
                                        <!-- Access Key ID -->
                                        <table width="100%%" cellpadding="0" cellspacing="0" style="margin-bottom: 20px;">
                                            <tr>
                                                <td>
                                                    <p style="margin: 0 0 8px 0; color: #667eea; font-size: 13px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px;">🔐 Access Key ID</p>
                                                    <div style="background-color: #ffffff; padding: 12px 16px; border-radius: 8px; border: 2px solid #e0e7ff;">
                                                        <p style="margin: 0; color: #1a1a1a; font-size: 16px; font-weight: 600; font-family: 'Courier New', monospace; word-break: break-all;">%s</p>
                                                    </div>
                                                </td>
                                            </tr>
                                        </table>
                                        
                                        <!-- Secret Access Key -->
                                        <table width="100%%" cellpadding="0" cellspacing="0">
                                            <tr>
                                                <td>
                                                    <p style="margin: 0 0 8px 0; color: #667eea; font-size: 13px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px;">🔑 Secret Access Key</p>
                                                    <div style="background-color: #ffffff; padding: 12px 16px; border-radius: 8px; border: 2px solid #e0e7ff;">
                                                        <p style="margin: 0; color: #1a1a1a; font-size: 16px; font-weight: 600; font-family: 'Courier New', monospace; word-break: break-all;">%s</p>
                                                    </div>
                                                </td>
                                            </tr>
                                        </table>
                                    </td>
                                </tr>
                            </table>
                            
                            <!-- Warning Box -->
                            <table width="100%%" cellpadding="0" cellspacing="0" style="background-color: #fff3cd; border-radius: 12px; border-left: 4px solid #ffc107; margin: 30px 0;">
                                <tr>
                                    <td style="padding: 20px;">
                                        <p style="margin: 0 0 15px 0; color: #856404; font-size: 16px; font-weight: 700;">⚠️ Important Security Notes:</p>
                                        <table width="100%%" cellpadding="0" cellspacing="0">
                                            <tr>
                                                <td style="padding: 4px 0;">
                                                    <p style="margin: 0; color: #856404; font-size: 14px; line-height: 1.6;">• This is the ONLY time you can view the secret access key</p>
                                                </td>
                                            </tr>
                                            <tr>
                                                <td style="padding: 4px 0;">
                                                    <p style="margin: 0; color: #856404; font-size: 14px; line-height: 1.6;">• Store these credentials securely (use a password manager)</p>
                                                </td>
                                            </tr>
                                            <tr>
                                                <td style="padding: 4px 0;">
                                                    <p style="margin: 0; color: #856404; font-size: 14px; line-height: 1.6;">• Never commit these keys to version control</p>
                                                </td>
                                            </tr>
                                            <tr>
                                                <td style="padding: 4px 0;">
                                                    <p style="margin: 0; color: #856404; font-size: 14px; line-height: 1.6;">• Never share your credentials with anyone</p>
                                                </td>
                                            </tr>
                                            <tr>
                                                <td style="padding: 4px 0;">
                                                    <p style="margin: 0; color: #856404; font-size: 14px; line-height: 1.6;">• Rotate your keys regularly</p>
                                                </td>
                                            </tr>
                                            <tr>
                                                <td style="padding: 4px 0;">
                                                    <p style="margin: 0; color: #856404; font-size: 14px; line-height: 1.6;">• Delete this email after saving the credentials</p>
                                                </td>
                                            </tr>
                                        </table>
                                    </td>
                                </tr>
                            </table>
                            
                            <p style="margin: 30px 0 20px 0; color: #333333; font-size: 16px; line-height: 1.6;">If you have any questions or need assistance, please contact your administrator.</p>
                            
                            <p style="margin: 30px 0 0 0; color: #333333; font-size: 16px; line-height: 1.6;">
                                Best regards,<br>
                                <strong style="color: #667eea;">%s</strong>
                            </p>
                        </td>
                    </tr>
                    
                    <!-- Footer -->
                    <tr>
                        <td style="background-color: #f8f9fa; padding: 25px 30px; text-align: center; border-top: 1px solid #e9ecef;">
                            <p style="margin: 0; color: #6c757d; font-size: 13px; line-height: 1.6;">
                                This is an automated message from AethrOps<br>
                                Please do not reply to this email
                            </p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>
`, username, accessKey, secretKey, config.SenderName)

	// Set plain text as base, then HTML as alternative (this ensures HTML is preferred)
	plainBody := fmt.Sprintf(`
AWS Access Keys
===============

Hello %s,

Your AWS programmatic access keys have been generated successfully.

Access Credentials:
-------------------
Access Key ID: %s
Secret Access Key: %s

⚠️ IMPORTANT SECURITY NOTES:
- This is the ONLY time you can view the secret access key
- Store these credentials securely (use a password manager)
- Never commit these keys to version control
- Never share your credentials with anyone
- Rotate your keys regularly
- Delete this email after saving the credentials

If you have any questions or need assistance, please contact your administrator.

Best regards,
%s

---
This is an automated message from AethrOps.
Please do not reply to this email.
`, username, accessKey, secretKey, config.SenderName)

	m.SetBody("text/plain", plainBody)
	m.AddAlternative("text/html", htmlBody)

	d := gomail.NewDialer(config.SMTPHost, config.SMTPPort, config.SenderEmail, config.SenderPass)

	if err := d.DialAndSend(m); err != nil {
		return fmt.Errorf("failed to send email: %v", err)
	}

	return nil
}

// SendTestEmail sends a verification email to check SMTP configuration
func SendTestEmail(config *EmailConfig, recipient string) error {
	if config == nil {
		return fmt.Errorf("email configuration is required")
	}

	m := gomail.NewMessage()
	m.SetHeader("From", fmt.Sprintf("%s <%s>", config.SenderName, config.SenderEmail))
	m.SetHeader("To", recipient)
	m.SetHeader("Subject", "AethrOps - Test Email")
	m.SetBody("text/plain", "This is a test email from AethrOps to verify your SMTP settings.\n\nIf you are reading this, your configuration is correct! ✅")

	d := gomail.NewDialer(config.SMTPHost, config.SMTPPort, config.SenderEmail, config.SenderPass)

	if err := d.DialAndSend(m); err != nil {
		return fmt.Errorf("failed to send email: %v", err)
	}

	return nil
}
