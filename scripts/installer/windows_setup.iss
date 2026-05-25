; AethrOps - Inno Setup Script
; This script creates a Windows installer for AethrOps

#define MyAppName "AethrOps"
#define MyAppVersion "Preview Beta 2"
#define MyAppVersionTag "preview-beta-2"
#define MyAppNumericVersion "0.1.0"
#define MyAppPublisher "DragonEmperor9480"
#define MyAppURL "https://github.com/DragonEmperor9480/AethrOps"
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
; Branding images
WizardSmallImageFile=assets\wizard_small_image.bmp
; Privileges
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog
; Minimum Windows version (Windows 10 - October 2018 Update)
MinVersion=10.0.17763
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
LicenseFile=..\..\LICENSE

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Copy ALL files from Release folder (includes all Flutter plugin DLLs)
Source: "..\..\awsmgr_ui\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Comment: "{#MyAppDescription}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; Comment: "{#MyAppDescription}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{localappdata}\aethrops"
Type: filesandordirs; Name: "{userappdata}\aethrops"

[Code]
// Detect an existing installation and notify the user of an in-place upgrade.
// InnoSetup matches installations via AppId, so files are overwritten automatically.

function GetInstalledVersion(): String;
var
  Ver: String;
begin
  Ver := '';
  if not RegQueryStringValue(HKLM,
    'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{A8F2B9C1-D4E5-4F6A-8B9C-1D2E3F4A5B6C}_is1',
    'DisplayVersion', Ver) then
    RegQueryStringValue(HKCU,
      'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{A8F2B9C1-D4E5-4F6A-8B9C-1D2E3F4A5B6C}_is1',
      'DisplayVersion', Ver);
  Result := Ver;
end;

function InitializeSetup(): Boolean;
var
  InstalledVersion: String;
begin
  Result := True;
  InstalledVersion := GetInstalledVersion();

  if InstalledVersion <> '' then
    MsgBox(
      'AethrOps ' + InstalledVersion + ' is already installed.' + #13#10 + #13#10 +
      'The installer will upgrade it in place. Your settings will be preserved.',
      mbInformation, MB_OK);
end;
