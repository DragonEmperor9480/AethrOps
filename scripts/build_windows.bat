@echo off
REM Build Windows desktop app with Go backend and create installer

echo ==========================================
echo Building AWS Manager for Windows
echo ==========================================

REM Change to project root (parent of scripts directory)
cd /d "%~dp0\.."
set PROJECT_ROOT=%cd%

REM Fetch version from GitHub version.json
echo Fetching version from GitHub...
for /f "tokens=*" %%i in ('powershell -Command "try { $json = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/DragonEmperor9480/aws-manager/awsmgr-gui/version.json' -TimeoutSec 10; $json.windows.version } catch { '' }"') do set VERSION=%%i

REM Fallback to local version.json if GitHub fetch fails
if "%VERSION%"=="" (
    echo GitHub fetch failed, trying local version.json...
    for /f "tokens=*" %%i in ('powershell -Command "try { $json = Get-Content 'version.json' | ConvertFrom-Json; $json.windows.version } catch { '' }"') do set VERSION=%%i
)

REM Final fallback
if "%VERSION%"=="" set VERSION=Preview Beta 1

echo Version: %VERSION%
echo.

echo Step 1: Building Go backend executable...
cd backend
set GOOS=windows
set GOARCH=amd64
go build -o awsmgr_backend.exe main.go

if %errorlevel% neq 0 (
    echo Failed to build Go backend
    exit /b 1
)

cd ..
echo Done: Go backend compiled: backend\awsmgr_backend.exe

echo.
echo Step 2: Building Flutter Windows app...
cd awsmgr_ui

call flutter clean
call flutter pub get
call flutter build windows --release

if %errorlevel% neq 0 (
    echo Failed to build Flutter app
    exit /b 1
)

echo.
echo Step 3: Copying backend to Flutter build...
copy ..\backend\awsmgr_backend.exe build\windows\x64\runner\Release\
echo Done: Backend copied to bundle

cd ..

echo.
echo Step 4: Creating release directory...
set RELEASE_DIR=%PROJECT_ROOT%\release\windows
if not exist "%RELEASE_DIR%" mkdir "%RELEASE_DIR%"

echo.
echo Step 5: Updating version in Inno Setup script...
REM Update display version (MyAppVersion) - keeps numeric version (MyAppNumericVersion) unchanged
powershell -Command "$content = Get-Content 'scripts\installer\windows_setup.iss' -Raw; $content = $content -replace '(?m)^#define MyAppVersion \"[^\"]*\"', '#define MyAppVersion \"%VERSION%\"'; Set-Content 'scripts\installer\windows_setup.iss' -Value $content -NoNewline"

echo.
echo Step 6: Building installer with Inno Setup...
echo.

REM Check for Inno Setup in common locations
set ISCC_PATH=
if exist "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" (
    set "ISCC_PATH=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
) else if exist "%ProgramFiles%\Inno Setup 6\ISCC.exe" (
    set "ISCC_PATH=%ProgramFiles%\Inno Setup 6\ISCC.exe"
) else if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" (
    set "ISCC_PATH=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
)

if "%ISCC_PATH%"=="" (
    echo.
    echo ==========================================
    echo WARNING: Inno Setup not found!
    echo ==========================================
    echo.
    echo Please install Inno Setup 6 from:
    echo   https://jrsoftware.org/isdl.php
    echo.
    echo After installing, run this script again to create the installer.
    echo.
    echo For now, creating a ZIP file instead...
    
    set ZIP_NAME=awsmgr-%VERSION%-windows-x64.zip
    if exist "%RELEASE_DIR%\%ZIP_NAME%" del "%RELEASE_DIR%\%ZIP_NAME%"
    powershell -Command "Compress-Archive -Path 'awsmgr_ui\build\windows\x64\runner\Release\*' -DestinationPath '%RELEASE_DIR%\%ZIP_NAME%' -Force"
    
    echo Done: ZIP created: release\windows\%ZIP_NAME%
    echo.
    goto :end
)

echo Using Inno Setup: %ISCC_PATH%
echo.

"%ISCC_PATH%" "scripts\installer\windows_setup.iss"

if %errorlevel% neq 0 (
    echo.
    echo Failed to create installer!
    echo Creating ZIP as fallback...
    
    set ZIP_NAME=awsmgr-%VERSION%-windows-x64.zip
    if exist "%RELEASE_DIR%\%ZIP_NAME%" del "%RELEASE_DIR%\%ZIP_NAME%"
    powershell -Command "Compress-Archive -Path 'awsmgr_ui\build\windows\x64\runner\Release\*' -DestinationPath '%RELEASE_DIR%\%ZIP_NAME%' -Force"
    
    echo Done: ZIP created: release\windows\%ZIP_NAME%
) else (
    echo.
    echo Done: Installer created successfully!
)

:end
echo.
echo ==========================================
echo Build Complete!
echo ==========================================
echo.
echo Build outputs in: release\windows\
echo.
if exist "%RELEASE_DIR%\awsmgr-setup-%VERSION%.exe" (
    echo   Installer: awsmgr-setup-%VERSION%.exe
    echo.
    echo Users can run the installer to:
    echo   - Install to Program Files
    echo   - Create Start Menu shortcuts
    echo   - Create Desktop shortcut (optional)
    echo   - Add uninstaller to Control Panel
)
if exist "%RELEASE_DIR%\awsmgr-%VERSION%-windows-x64.zip" (
    echo   Portable: awsmgr-%VERSION%-windows-x64.zip
)
echo.
pause
