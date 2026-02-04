# AethrOps – Preview Beta 2

## Supported Platforms
- **Android:** ARM64, ARM32, x86_64  
- **Windows:** Installer  
- **Linux:** AppImage  

---

## Changelog Highlights

### Branding & Design
- Complete rebranding from **AWS Manager** to **AethrOps**
- Improved Dark Mode experience
- Revamped Email Configuration UI
- Refactored headers across all services
- IAM UI enhancements
- Removed unused service cards

### Features & Enhancements
- Initial EC2 implementation with basic filtering criteria
- Integrated AWS official icons across the application
- New S3 Search Bar with significant performance improvements
- Added **Test Email** option for SMTP configuration
- Unified success/failure toast notification system
- Region display added to the Home Screen
- Improved **Attach Policies** workflow for User Groups

### Stability & Performance
- Added backend shutdown confirmation popup on application close  
  *(Prevents backend services from running after the app exits)*
- General performance improvements and smoother UI interactions

---

## Why the Name Change?
The project has been renamed from **AWS Manager** to **AethrOps** to better align with a modern, unique identity.  
Additionally, the previous name conflicted with AWS branding guidelines, which prohibit naming third-party tools in a way that implies official AWS affiliation.

📘 **Documentation & Guides**  
We will be adding detailed documentation and step-by-step guides very soon to help users get started and explore advanced features.

---

## 🔑 Getting Started – AWS Credentials Setup

To use **AethrOps**, you'll need AWS Access Keys. Follow the steps below to generate and configure them.

### Step 1: Create an IAM User (if you don’t have one)
1. Log in to the AWS Management Console  
2. Navigate to **IAM → Users → Create user**  
3. Enter a username and click **Next**  
4. Attach required policies  
   - Example: `AdministratorAccess` (full access)  
   - Or specific policies for limited access  
5. Click **Create user**

---

### Step 2: Generate Access Keys
1. Go to **IAM → Users → Select your user**  
2. Open the **Security credentials** tab  
3. Scroll to **Access keys** → Click **Create access key**  
4. Select **Application running outside AWS** → Click **Next**  
5. *(Optional)* Add a description → Click **Create access key**

⚠️ **Important:**  
Copy both keys immediately. The **Secret Access Key** is shown only once.

---

### Step 3: Configure AethrOps
1. Open the **AethrOps** application  
2. When prompted, enter your AWS credentials:
   - **Access Key ID:** 20-character Access Key ID  
   - **Secret Access Key:** 40-character Secret Access Key  
   - **Region:** Preferred AWS region (e.g., `us-east-1`)
3. Tap **Save**

🎉 You’re now ready to manage your AWS resources!

---

## 🚀 Features Coming in Future Releases
- Expanded AMI selection for EC2
- Revamped **Live Tail** experience
- Login flow improvements
- Additional enhancements as the project evolves through beta

---

## New Sub-Project Addition: AethrBuild

**AethrBuild** is an automated GitHub Actions workflow that:
- Builds applications for all supported platforms
- Handles release generation
- Updates the official website
- Publishes release announcements on LinkedIn

---

<footer>

**Made by Developers for Developers ❤️**

</footer>
