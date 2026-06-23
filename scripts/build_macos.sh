#!/bin/bash
# Build macOS desktop app with Go backend
# Compiles a universal binary (amd64 + arm64) for maximum compatibility

set -e

echo "=========================================="
echo "Building AethrOps for macOS"
echo "=========================================="

# Change to project root
cd "$(dirname "$0")/.."
PROJECT_ROOT=$(pwd)

# Fetch version and build number from GitHub
echo ""
echo "Fetching version and build number from GitHub..."
GITHUB_JSON=$(curl -s --max-time 10 "https://raw.githubusercontent.com/DragonEmperor9480/aethrops/awsmgr-gui/version.json" 2>/dev/null)

VERSION=""
BUILD_NUMBER=""

if [ -n "$GITHUB_JSON" ]; then
    # Try jq first, fall back to python
    if command -v jq &> /dev/null; then
        VERSION=$(echo "$GITHUB_JSON" | jq -r '.macos.version' 2>/dev/null)
        BUILD_NUMBER=$(echo "$GITHUB_JSON" | jq -r '.macos.build_number' 2>/dev/null)
    elif command -v python3 &> /dev/null; then
        VERSION=$(echo "$GITHUB_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('macos',{}).get('version',''))" 2>/dev/null)
        BUILD_NUMBER=$(echo "$GITHUB_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('macos',{}).get('build_number',1))" 2>/dev/null)
    fi
fi

# Fallback to local version.json
if [ -z "$VERSION" ] || [ "$VERSION" = "null" ] || [ -z "$BUILD_NUMBER" ] || [ "$BUILD_NUMBER" = "null" ]; then
    if [ -f "version.json" ]; then
        echo "GitHub fetch failed, trying local version.json..."
        if command -v jq &> /dev/null; then
            VERSION=$(jq -r '.macos.version' version.json 2>/dev/null)
            BUILD_NUMBER=$(jq -r '.macos.build_number' version.json 2>/dev/null)
        elif command -v python3 &> /dev/null; then
            VERSION=$(python3 -c "import json; print(json.load(open('version.json')).get('macos',{}).get('version',''))" 2>/dev/null)
            BUILD_NUMBER=$(python3 -c "import json; print(json.load(open('version.json')).get('macos',{}).get('build_number',1))" 2>/dev/null)
        fi
    fi
fi

# Final fallback
if [ -z "$VERSION" ] || [ "$VERSION" = "null" ]; then
    VERSION="1.0.0"
fi
if [ -z "$BUILD_NUMBER" ] || [ "$BUILD_NUMBER" = "null" ]; then
    BUILD_NUMBER="1"
fi

echo "Version: $VERSION"
echo "Build Number: $BUILD_NUMBER"

echo ""
echo "Step 1: Building Go backend executable for macOS (Universal Binary)..."
cd backend
export AETHROPS_VERSION="$VERSION"
export AETHROPS_BUILD_NUMBER="$BUILD_NUMBER"

echo "Compiling darwin/amd64 binary..."
GOOS=darwin GOARCH=amd64 go build -ldflags "-X 'github.com/DragonEmperor9480/AethrOps/models.Version=$VERSION' -X 'github.com/DragonEmperor9480/AethrOps/models.BuildNumberStr=$BUILD_NUMBER'" -o aethrops_core_macos_amd64 main.go

echo "Compiling darwin/arm64 binary..."
GOOS=darwin GOARCH=arm64 go build -ldflags "-X 'github.com/DragonEmperor9480/AethrOps/models.Version=$VERSION' -X 'github.com/DragonEmperor9480/AethrOps/models.BuildNumberStr=$BUILD_NUMBER'" -o aethrops_core_macos_arm64 main.go

if command -v lipo &> /dev/null; then
    echo "Creating universal binary using lipo..."
    lipo -create -output aethrops_core_macos aethrops_core_macos_amd64 aethrops_core_macos_arm64
    rm aethrops_core_macos_amd64 aethrops_core_macos_arm64
else
    echo "⚠️ 'lipo' command not found. Falling back to native/host architecture..."
    ARCH=$(uname -m)
    if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
        cp aethrops_core_macos_arm64 aethrops_core_macos
    else
        cp aethrops_core_macos_amd64 aethrops_core_macos
    fi
    rm aethrops_core_macos_amd64 aethrops_core_macos_arm64
fi

cd ..

if [ ! -f backend/aethrops_core_macos ]; then
    echo "❌ Failed to build Go backend"
    exit 1
fi

chmod +x backend/aethrops_core_macos
echo "✓ Go backend compiled: backend/aethrops_core_macos"

echo ""
echo "Step 2: Building Flutter macOS app..."
cd awsmgr_ui

flutter clean
flutter pub get
flutter build macos --release

if [ $? -ne 0 ]; then
    echo "❌ Failed to build Flutter app"
    exit 1
fi

echo ""
echo "Step 3: Copying backend to Flutter build..."
cp ../backend/aethrops_core_macos build/macos/Build/Products/Release/aethrops.app/Contents/MacOS/
chmod +x build/macos/Build/Products/Release/aethrops.app/Contents/MacOS/aethrops_core_macos
echo "✓ Backend copied to app bundle"

cd ..

echo ""
echo "=========================================="
echo "✓ Build Complete!"
echo "=========================================="
echo "App location: awsmgr_ui/build/macos/Build/Products/Release/aethrops.app"
echo ""
echo "To run:"
echo "  open awsmgr_ui/build/macos/Build/Products/Release/aethrops.app"
echo ""
