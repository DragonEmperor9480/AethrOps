@echo off
REM Build Windows desktop app with Go backend and create MSIX package for Microsoft Store

echo ==========================================
echo Building AethrOps MSIX for Microsoft Store
echo ==========================================

REM Change to project root (parent of scripts directory)
cd /d "%~dp0\.."
set PROJECT_ROOT=%cd%

REM Read version from local version.json (windows key)
echo Reading version from version.json...

REM Get display version (e.g., "Preview Beta 2")
for /f "tokens=*" %%i in ('powershell -Command "try { (Get-Content 'version.json' | ConvertFrom-Json).windows.version } catch { '' }"') do set VERSION_DISPLAY=%%i

REM Get normalized version for filenames (e.g., "preview-beta-2")
for /f "tokens=*" %%i in ('powershell -Command "try { $v = (Get-Content 'version.json' | ConvertFrom-Json).windows.version; $v.ToLower().Replace(' ', '-') } catch { '' }"') do set VERSION=%%i

REM Fallback if version.json read fails
if "%VERSION_DISPLAY%"=="" set VERSION_DISPLAY=Preview Beta 3
if "%VERSION%"=="" set VERSION=preview-beta-3

echo Display Version: %VERSION_DISPLAY%
echo Tag Version: %VERSION%
echo.

echo Step 1: Building Go backend executable...
cd backend
set GOOS=windows
set GOARCH=amd64
go build -o aethrops_core.exe main.go

if %errorlevel% neq 0 (
    echo Failed to build Go backend
    exit /b 1
)

cd ..
echo Done: Go backend compiled: backend\aethrops_core.exe

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
copy ..\backend\aethrops_core.exe build\windows\x64\runner\Release\
echo Done: Backend copied to bundle


echo.
echo Step 4: Creating MSIX package...
echo.

call dart run msix:create

if %errorlevel% neq 0 (
    echo.
    echo Failed to create MSIX package!
    echo.
    echo Make sure the msix package is in your pubspec.yaml dev_dependencies.
    echo Run: flutter pub get
    exit /b 1
)

echo.
echo Step 5: Copying MSIX to release directory...
set RELEASE_DIR=%PROJECT_ROOT%\release\windows
if not exist "%RELEASE_DIR%" mkdir "%RELEASE_DIR%"

REM Find and copy the generated .msix file
for /f "tokens=*" %%f in ('dir /b /s build\windows\*.msix 2^>nul') do (
    copy "%%f" "%RELEASE_DIR%\AethrOps-%VERSION%.msix"
    echo Copied: AethrOps-%VERSION%.msix
)

cd ..

echo.
echo ==========================================
echo MSIX Build Complete!
echo ==========================================
echo.
echo Build output: release\windows\AethrOps-%VERSION%.msix
echo.
echo Next steps for Microsoft Store submission:
echo   1. Sign in to Partner Center: https://partner.microsoft.com/dashboard
echo   2. Create a new app submission
echo   3. Upload the .msix package
echo   4. Fill in the Store listing details
echo   5. Submit for certification
echo.
echo NOTE: The MSIX is built with 'store: true' in msix_config,
echo       so it is unsigned and ready for Store signing via Partner Center.
echo.
pause
