# AethrOps

**AethrOps** is a modern, cross-platform AWS management tool built to simplify cloud operations for developers through a clean UI, efficient workflows, and platform-wide availability.

<p align="center">
  <a href="#about">About</a> •
  <a href="#features">Features</a> •
  <a href="#supported-platforms">Downloads</a> •
  <a href="#-getting-started--aws-credentials-setup">Getting Started</a> •
  <a href="#aethrbuild--the-builder-of-aethrops">AethrBuild</a>
</p>

---

## About

AethrOps is designed to make managing AWS services simple and intuitive. With a clean, user-friendly interface, it allows you to control AWS resources directly from your mobile device or PC—without repeatedly logging into the AWS Management Console.

The core goal of AethrOps is to make AWS **easy**, **accessible**, and **portable** for everyone, enabling seamless cloud management anytime, anywhere.

---

## Supported Platforms

You can download **AethrOps** for **Android**, **Windows**, and **Linux** directly from our GitHub Releases page.

[**📥 Download Latest Version**](https://github.com/DragonEmperor9480/AethrOps/releases/latest)  

---

##  Features

### 🛡️ IAM (Identity & Access Management)
- **User & Group Management:** Create, delete, and manage IAM users and groups.
- **Batch User Creation:** Create multiple users simultaneously in a single operation.
- **Force Delete:** Recursively delete users and groups, even with attached policies or active members.
- **Policy Attachment:** Seamlessly attach policies to users and groups.
- **Smart Credential Delivery:** Automatically compose emails with credentials for new users.

### ☁️ EC2 (Elastic Compute Cloud)
- **Instance Dashboard:** View, filter, and monitor your EC2 instances.
- **Lifecycle Control:** Start, Stop, Reboot, and Terminate instances directly.
- **Deep Inspection:** Detailed view of Network interfaces, Security Groups, Storage volumes, and Tags.
- **Status Tracking:** Real-time updates on instance states (Pending, Running, Stopping, etc.).

### 🗄️ S3 (Simple Storage Service)
- **Object Management:** Upload, Download, and Delete files; Create Folders.
- **Bucket Operations:** Create and delete S3 buckets easily.
- **Versioning Control:** Enable or disable bucket versioning.
- **MFA Protection:** Configure MFA Delete for critical buckets.
- **Bucket Browser:** Navigate folders and explore your S3 hierarchy.
- **Instant Search:** High-performance search bar to find buckets and objects quickly.

### 📊 Monitoring & Logs
- **Lambda Live Logs:** Real-time log streaming for AWS Lambda functions.
- **Custom Log Viewer:** Built-in viewer for easy log analysis.

### ✨ Core Capabilities
- **Cross-Platform:** Native experience on Android, Windows, and Linux.
- **Secure Storage:** AWS credentials are encrypted and stored locally.
- **Multi-Region Support:** Manage resources across different AWS regions.

---

## 🔑 Getting Started – AWS Credentials Setup

To use **AethrOps**, AWS Access Keys are required.

### Step 1: Create an IAM User
1. Log in to the AWS Management Console  
2. Navigate to **IAM → Users → Create user**  
3. Enter a username and proceed  
4. Attach appropriate policies  
   - `AdministratorAccess` for full access  
   - Or specific policies for limited permissions  
5. Create the user

---

### Step 2: Generate Access Keys
1. Go to **IAM → Users → Select your user**  
2. Open **Security credentials**  
3. Under **Access keys**, click **Create access key**  
4. Select **Application running outside AWS**  
5. Complete the process

⚠️ **Important:**  
Save the **Access Key ID** and **Secret Access Key** immediately.  
The secret key is shown only once.

---

### Step 3: Configure AethrOps
1. Open the **AethrOps** application  
2. Enter the following:
   - **Access Key ID**
   - **Secret Access Key**
   - **AWS Region** (e.g., `us-east-1`, `ap-south-1`)
3. Save the configuration

🎉 You’re now ready to manage your AWS resources using AethrOps.

---

📘 **Documentation & Guides**  
Detailed documentation and step-by-step guides will be added soon.

---

## AethrBuild – The Builder of AethrOps

**AethrBuild** is an automated GitHub Actions workflow that:
- Builds AethrOps for all supported platforms
- Manages releases
- Updates the official website
- Publishes release announcements on LinkedIn

---

## Project Lineage

AethrOps is the evolution of the earlier CLI-based AWS management tool **awsmgr**:  
https://github.com/DragonEmperor9480/awsmgr

This project builds upon the ideas and experience gained from **awsmgr**, expanding them into a full-featured, cross-platform application.

---

**Made by Developers for Developers ❤️**
