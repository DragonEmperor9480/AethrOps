<p align="center">
  <img src="Assets/AethrOpsBanner.png" alt="AethrOps banner" />
</p>

<p align="center">
  <strong>Cloud operations without living in the AWS Console.</strong>
  <br />
  A cross-platform AWS management app built with Flutter and Go for fast, local-first workflows across desktop and mobile.
</p>

<p align="center">
  <a href="https://github.com/DragonEmperor9480/AethrOps/releases/latest">
    <img src="https://img.shields.io/github/v/release/DragonEmperor9480/AethrOps?style=for-the-badge" alt="Latest release" />
  </a>
  <a href="https://github.com/DragonEmperor9480/AethrOps/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/DragonEmperor9480/AethrOps?style=for-the-badge" alt="GPL-3.0 license" />
  </a>
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20Windows%20%7C%20Linux-111827?style=for-the-badge" alt="Platforms" />
  <img src="https://img.shields.io/badge/Frontend-Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter frontend" />
  <img src="https://img.shields.io/badge/Backend-Go-00ADD8?style=for-the-badge&logo=go&logoColor=white" alt="Go backend" />
</p>

<p align="center">
  <a href="https://github.com/DragonEmperor9480/AethrOps/releases/latest"><strong>Download Latest Release</strong></a>
  ·
  <a href="#what-you-can-do"><strong>Features</strong></a>
  ·
  <a href="#quick-start"><strong>Quick Start</strong></a>
  ·
  <a href="#for-developers"><strong>For Developers</strong></a>
</p>

> [!IMPORTANT]
> AethrOps is an independent developer tool for AWS users. It is not an official AWS product and is not affiliated with Amazon Web Services.

## Why AethrOps

AethrOps is designed for developers and operators who want to manage AWS resources from a focused app instead of constantly bouncing through the browser console.

- Manage common AWS workflows from one interface across Android, Windows, and Linux.
- Keep the experience local-first with a Flutter UI and a Go backend running on your machine.
- Handle day-to-day operations faster, from IAM onboarding to S3 file work and EC2 control.
- Add device-level protection with PIN lock and biometric authentication where supported.

## Download

You can download the latest AethrOps release for Android, Windows, and Linux directly from GitHub.

<p align="center">
  <a href="https://github.com/DragonEmperor9480/AethrOps/releases/latest"><strong>Get AethrOps</strong></a>
</p>

## What You Can Do

| Area | Highlights |
| --- | --- |
| `IAM` | Create and delete users and groups, batch-create IAM users, attach policies, inspect dependencies, and force-delete complex resources. |
| `EC2` | View instances, filter and inspect details, and run start, stop, reboot, or terminate actions without opening the AWS Console. |
| `S3` | Create buckets, browse folders, upload and download objects, delete files, manage versioning, and configure MFA Delete. |
| `CloudWatch` | Stream AWS Lambda logs in real time with an in-app viewer built for quick inspection. |
| `Security` | Store app security state locally, protect access with a PIN, and enable biometrics on supported mobile devices. |
| `Utility` | Configure SMTP for credential delivery, switch AWS regions, and work through a cleaner cross-platform UI. |

## Supported Platforms

| Platform | Package | Notes |
| --- | --- | --- |
| Android | Split APKs | Targets `arm64-v8a`, `armeabi-v7a`, and `x86_64` release builds. |
| Windows | Installer / portable bundle | Windows packaging is handled by the build scripts and installer setup. |
| Linux | AppImage | Linux desktop builds are packaged for easy distribution. |

## Quick Start

1. Download the latest build for your platform from the releases page.
2. Create or choose an IAM user with the permissions you want AethrOps to use.
3. Generate an access key pair for that IAM user.
4. Open AethrOps and enter:
   - `Access Key ID`
   - `Secret Access Key`
   - `AWS Region` such as `us-east-1` or `ap-south-1`
5. Save the configuration and start managing your resources.

<details>
<summary><strong>Need help creating AWS access keys?</strong></summary>

1. Sign in to the AWS Management Console.
2. Open `IAM -> Users`.
3. Create a new user, or select an existing one.
4. Attach the policies you want that user to have.
5. Open the `Security credentials` tab.
6. Under `Access keys`, choose `Create access key`.
7. Select `Application running outside AWS`.
8. Save the `Access Key ID` and `Secret Access Key` immediately. The secret is only shown once.

### Visual Reference

<table>
  <tr>
    <td width="50%" align="center">
      <img src="awsmgr_ui/assets/how_to_get_access_credentials/1_aws_console_homepage" alt="AWS Console homepage" width="100%" />
      <br />
      <sub>Open IAM from the AWS Console.</sub>
    </td>
    <td width="50%" align="center">
      <img src="awsmgr_ui/assets/how_to_get_access_credentials/2_aws_security_credentials_page" alt="AWS security credentials page" width="100%" />
      <br />
      <sub>Open the Security credentials tab.</sub>
    </td>
  </tr>
  <tr>
    <td width="50%" align="center">
      <img src="awsmgr_ui/assets/how_to_get_access_credentials/3_choosing_thrid_party_service_in_create_access_key" alt="Choose application running outside AWS" width="100%" />
      <br />
      <sub>Choose Application running outside AWS.</sub>
    </td>
    <td width="50%" align="center">
      <img src="awsmgr_ui/assets/how_to_get_access_credentials/4_final%20retrive_access_keys_page" alt="Generated access keys page" width="100%" />
      <br />
      <sub>Copy the generated access keys immediately.</sub>
    </td>
  </tr>
</table>

</details>

## Why It Feels Different

- You work from a dedicated app instead of jumping across AWS Console pages.
- Common actions are easier to reach, especially for repetitive IAM, EC2, and S3 work.
- The experience is designed to be portable across desktop and mobile.
- Security controls like PIN lock and biometrics help protect access on supported devices.

## For Developers

If you're exploring the codebase, contributing, or building releases, everything below is focused on the development side of AethrOps.

### Architecture

| Layer | Stack | Purpose |
| --- | --- | --- |
| UI | Flutter + Dart | Shared desktop and mobile interface. |
| Desktop backend | Go + Gorilla Mux | Local API server on `127.0.0.1:9480` for desktop builds. |
| Android backend | Go shared library + FFI | Embedded backend for Android packaging. |
| Data | SQLite + local device storage | Stores configuration and local app state. |
| AWS integration | AWS SDK for Go v2 | Talks directly to IAM, EC2, S3, Lambda, CloudWatch Logs, and STS. |

### Repository Layout

```text
AethrOps/
|- awsmgr_ui/     Flutter application
|- backend/       Go HTTP backend for desktop
|- backend_ffi/   Go shared library for Android
|- scripts/       Build, packaging, and helper scripts
|- version.json   Release metadata
`- README.md
```

### Build from Source

#### Prerequisites

- Flutter SDK
- Go `1.24+`
- Android NDK for Android builds

#### Common commands

Run the Linux desktop app in development mode:

```bash
./scripts/run_linux.sh
```

Build the Linux desktop release:

```bash
./scripts/build_linux.sh
```

Build Android release APKs:

```bash
./scripts/build_android.sh
```

Build the Windows release package:

```powershell
scripts\build_windows.bat
```

Additional packaging helpers for AppImage, Debian, macOS, installers, and release automation live in [`scripts/`](scripts/).

### AethrBuild

`AethrBuild` is the automation layer behind AethrOps releases. It is used to:

- build supported platform packages,
- prepare releases,
- update the official website,
- and publish release announcements.

### Project Lineage

AethrOps is the evolution of the earlier CLI-based AWS manager, [`awsmgr`](https://github.com/DragonEmperor9480/awsmgr). The current project carries that idea forward into a full cross-platform application with a dedicated UI, local backend services, and mobile support.

## License & Privacy

*   Released under the [GNU GPL v3 License](LICENSE).
*   Read our [Privacy Policy](PRIVACY.md).

<p align="center">
  <strong>Made by developers, for developers.</strong>
</p>
