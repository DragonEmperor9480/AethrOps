# Privacy Policy

**Last Updated: May 26, 2026**

AethrOps is built from the ground up as a **local-first, open-source application** to help you manage your AWS cloud infrastructure efficiently. Because we believe in absolute transparency, your privacy and data security are our highest priority. 

---

## 1. Our Core Philosophy: Local-First
AethrOps is designed to run entirely on your own local device (desktop or mobile). We do not host or operate a centralized server, database, or analytics platform. 
*   **Your data belongs to you.** 
*   We do not collect, monitor, store, or transmit your personal information, AWS credentials, or usage statistics to any external servers of our own or any third-party analytics company.

---

## 2. Information Handled by AethrOps

### A. AWS Credentials
To interact with your AWS account, AethrOps requires your standard AWS access credentials:
*   `AWS Access Key ID`
*   `AWS Secret Access Key`
*   `AWS Session Token` (if using temporary credentials)
*   `AWS Region` (e.g., `us-east-1`)

**How they are handled:**
*   These credentials are input directly into the app by you.
*   They are **stored strictly on your local device** using the secure, encrypted device storage mechanisms (e.g., secure keychains or local shared preferences).
*   They are never uploaded, sent, or exposed to any server other than directly to the official **Amazon Web Services (AWS) endpoints** to authenticate your API requests.

### B. Cloud Infrastructure Details
Any data retrieved from your AWS account—such as lists of IAM users, EC2 instance states, S3 bucket listings, or CloudWatch Live Tail logs—is fetched dynamically in real-time.
*   This information is processed directly in memory on your device to build the visual interface.
*   It is **never stored or cached** on any external server. 

### C. Application Security (PIN & Biometrics)
If you enable PIN lock or Biometric authentication (Face ID, Fingerprint, or Touch ID) inside the application:
*   The authentication is handled locally by your device's native operating system.
*   AethrOps never collects, views, or stores your actual biometric data or passcode.

---

## 3. Data Transmission (Direct API Connections)
All network requests triggered by AethrOps are made **directly from your local device to the official AWS API endpoints** (e.g., `*.amazonaws.com`).
*   There is no middle-man server, proxy, or relay.
*   All data transmission is encrypted in transit using industry-standard Secure Sockets Layer (SSL) / Transport Layer Security (TLS) HTTPS connections.

---

## 4. Third-Party Integrations
If you utilize voluntary, user-configured third-party integrations inside the app:
*   **SMTP Mail Server**: If you choose to configure custom SMTP settings to email newly created IAM user credentials, the emails are delivered directly through the SMTP server you configure. These emails are subject to the privacy policy of your chosen SMTP mail service provider.

---

## 5. Zero Analytics, Tracking, or Telemetry
We do not use tracking cookies, analytics packages, telemetry reporting, crash logging servers (like Crashlytics), or advertisements. Your activity within the app remains entirely private and invisible to us.

---

## 6. Open Source Transparency
Because AethrOps is licensed under the **GNU General Public License v3 (GPL v3)**, our entire codebase is fully open-source. You, your organization's security team, or independent audits can inspect every single line of our frontend and backend source code at any time to verify that your credentials and data are handled precisely as described in this policy:

👉 [Visit the AethrOps GitHub Repository](https://github.com/DragonEmperor9480/AethrOps)

---

## 7. Contact and Inquiries
If you have any questions, feedback, or security concerns regarding this Privacy Policy, please open a public discussion or file an issue on our GitHub repository:

👉 [AethrOps GitHub Issues](https://github.com/DragonEmperor9480/AethrOps/issues)
