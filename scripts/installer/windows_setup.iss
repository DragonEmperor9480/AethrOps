; AethrOps - Inno Setup Script
; This script creates a Windows installer for AethrOps

#define MyAppName "AethrOps"
#define MyAppVersion "Preview Beta 2"
#define MyAppVersionTag "preview-beta-2"
#define MyAppNumericVersion "0.1.0"
#define MyAppPublisher "DragonEmperor9480"
#define MyAppURL "https://github.com/DragonEmperor9480/aws-manager"
#define MyAppExeName "AethrOps.exe"
#define MyAppDescription "AWS Resource Management Tool"

[Setup]
; Application info
AppId={{A8F2B9C1-D4E5-4F6A-8B9C-1D2E3F4A5B6C}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
AppUpdatesURL={#MyAppURL}/releases
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
; Output settings
OutputDir=..\..\release\windows
OutputBaseFilename=AethrOps-setup-{#MyAppVersionTag}
; Installer settings
SetupIconFile=..\..\awsmgr_ui\windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
; Privileges
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog
; Architecture
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Uninstall info
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
; Version info for installer (must be numeric x.x.x.x format)
VersionInfoVersion={#MyAppNumericVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppDescription} Setup
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppNumericVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1; Check: not IsAdminInstallMode

[Files]
; Copy ALL files from Release folder (includes all Flutter plugin DLLs)
Source: "..\..\awsmgr_ui\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Backend executable (copied by build script)
Source: "..\..\awsmgr_ui\build\windows\x64\runner\Release\awsmgr_backend.exe"; DestDir: "{app}"; Flags: ignoreversion
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Comment: "{#MyAppDescription}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; Comment: "{#MyAppDescription}"
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: quicklaunchicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{localappdata}\awsmgr"
Type: filesandordirs; Name: "{userappdata}\awsmgr"

[Code]
// Custom code for installation checks
function InitializeSetup(): Boolean;
begin
  Result := True;
end;

// Check if running on Windows 10 or later (recommended)
function IsWindows10OrLater(): Boolean;
begin
  Result := (GetWindowsVersion >= $0A000000);
end;

procedure InitializeWizard();
begin
  if not IsWindows10OrLater() then
  begin
    MsgBox('Note: AethrOps is optimized for Windows 10 and later. It may work on older versions but is not officially supported.', mbInformation, MB_OK);
  end;
end;
