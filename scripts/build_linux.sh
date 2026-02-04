#!/bin/bash
# Build Linux desktop app with Go backend

set -e

echo "=========================================="
echo "Building AWS Manager for Linux"
echo "=========================================="

# Change to project root
cd "$(dirname "$0")/.."
PROJECT_ROOT=$(pwd)

# Fetch version from GitHub
echo ""
echo "Fetching version from GitHub..."
GITHUB_JSON=$(curl -s --max-time 10 "https://raw.githubusercontent.com/DragonEmperor9480/aws-manager/awsmgr-gui/version.json" 2>/dev/null)

if [ -n "$GITHUB_JSON" ]; then
    # Try jq first, fall back to python, then grep
    if command -v jq &> /dev/null; then
        VERSION=$(echo "$GITHUB_JSON" | jq -r '.linux.version' 2>/dev/null)
    elif command -v python3 &> /dev/null; then
        VERSION=$(echo "$GITHUB_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('linux',{}).get('version',''))" 2>/dev/null)
    fi
fi

# Fallback to local version.json
if [ -z "$VERSION" ] || [ "$VERSION" = "null" ]; then
    if [ -f "version.json" ]; then
        echo "GitHub fetch failed, trying local version.json..."
        if command -v jq &> /dev/null; then
            VERSION=$(jq -r '.linux.version' version.json 2>/dev/null)
        elif command -v python3 &> /dev/null; then
            VERSION=$(python3 -c "import json; print(json.load(open('version.json')).get('linux',{}).get('version',''))" 2>/dev/null)
        fi
    fi
fi

# Final fallback
if [ -z "$VERSION" ] || [ "$VERSION" = "null" ]; then
    VERSION="Preview Beta 1"
fi

echo "Version: $VERSION"

echo ""
echo "Step 1: Building Go backend executable..."
cd backend
GOOS=linux GOARCH=amd64 go build -o awsmgr_backend main.go
cd ..

if [ $? -ne 0 ]; then
    echo "❌ Failed to build Go backend"
    exit 1
fi

chmod +x backend/awsmgr_backend
echo "✓ Go backend compiled: backend/awsmgr_backend"

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
cp ../backend/awsmgr_backend build/linux/x64/release/bundle/
chmod +x build/linux/x64/release/bundle/awsmgr_backend
echo "✓ Backend copied to bundle"

# Rename binary to aws-manager
mv build/linux/x64/release/bundle/aethrops build/linux/x64/release/bundle/aws-manager

cd ..

echo ""
echo "=========================================="
echo "✓ Build Complete!"
echo "=========================================="
echo "App location: awsmgr_ui/build/linux/x64/release/bundle/"
echo ""
echo "To run:"
echo "  cd awsmgr_ui/build/linux/x64/release/bundle/"
echo "  ./aws-manager"

