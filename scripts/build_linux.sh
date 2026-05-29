#!/bin/bash
# Build Linux desktop app with Go backend

set -e

echo "=========================================="
echo "Building AethrOps for Linux"
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
        VERSION=$(echo "$GITHUB_JSON" | jq -r '.linux.version' 2>/dev/null)
        BUILD_NUMBER=$(echo "$GITHUB_JSON" | jq -r '.linux.build_number' 2>/dev/null)
    elif command -v python3 &> /dev/null; then
        VERSION=$(echo "$GITHUB_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('linux',{}).get('version',''))" 2>/dev/null)
        BUILD_NUMBER=$(echo "$GITHUB_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('linux',{}).get('build_number',1))" 2>/dev/null)
    fi
fi

# Fallback to local version.json
if [ -z "$VERSION" ] || [ "$VERSION" = "null" ] || [ -z "$BUILD_NUMBER" ] || [ "$BUILD_NUMBER" = "null" ]; then
    if [ -f "version.json" ]; then
        echo "GitHub fetch failed, trying local version.json..."
        if command -v jq &> /dev/null; then
            VERSION=$(jq -r '.linux.version' version.json 2>/dev/null)
            BUILD_NUMBER=$(jq -r '.linux.build_number' version.json 2>/dev/null)
        elif command -v python3 &> /dev/null; then
            VERSION=$(python3 -c "import json; print(json.load(open('version.json')).get('linux',{}).get('version',''))" 2>/dev/null)
            BUILD_NUMBER=$(python3 -c "import json; print(json.load(open('version.json')).get('linux',{}).get('build_number',1))" 2>/dev/null)
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
echo "Step 1: Building Go backend executable..."
cd backend
export AETHROPS_VERSION="$VERSION"
export AETHROPS_BUILD_NUMBER="$BUILD_NUMBER"
GOOS=linux GOARCH=amd64 go build -ldflags "-X 'github.com/DragonEmperor9480/AethrOps/models.Version=$VERSION' -X 'github.com/DragonEmperor9480/AethrOps/models.BuildNumberStr=$BUILD_NUMBER'" -o aethrops_core main.go
cd ..

if [ $? -ne 0 ]; then
    echo "❌ Failed to build Go backend"
    exit 1
fi

chmod +x backend/aethrops_core
echo "✓ Go backend compiled: backend/aethrops_core"

echo ""
echo "Step 2: Building Flutter Linux app..."
cd awsmgr_ui

flutter clean
flutter pub get
flutter build linux --release

if [ $? -ne 0 ]; then
    echo "❌ Failed to build Flutter app"
    exit 1
fi

echo ""
echo "Step 3: Copying backend to Flutter build..."
cp ../backend/aethrops_core build/linux/x64/release/bundle/
chmod +x build/linux/x64/release/bundle/aethrops_core
echo "✓ Backend copied to bundle"

cd ..

echo ""
echo "=========================================="
echo "✓ Build Complete!"
echo "=========================================="
echo "App location: awsmgr_ui/build/linux/x64/release/bundle/"
echo ""
echo "To run:"
echo "  cd awsmgr_ui/build/linux/x64/release/bundle/"
echo "  ./aethrops"
