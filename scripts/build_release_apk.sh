#!/bin/bash

# ============================================
# AWS Manager - Release APK Build Script
# ============================================
# Builds and signs APKs for GitHub release

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FLUTTER_DIR="$PROJECT_ROOT/awsmgr_ui"
ANDROID_DIR="$FLUTTER_DIR/android"
OUTPUT_DIR="$PROJECT_ROOT/release"
VERSION="preview-beta-1"

echo "============================================"
echo "  AWS Manager - Release APK Builder"
echo "============================================"
echo ""

# Check if key.properties exists
if [ ! -f "$ANDROID_DIR/key.properties" ]; then
    echo "❌ Error: key.properties not found!"
    echo ""
    echo "Run the keystore generation script first:"
    echo "  ./scripts/generate_keystore.sh"
    echo ""
    exit 1
fi

# Check if keystore exists
if [ ! -f "$ANDROID_DIR/app/upload-keystore.jks" ]; then
    echo "❌ Error: Keystore not found!"
    echo ""
    echo "Run the keystore generation script first:"
    echo "  ./scripts/generate_keystore.sh"
    echo ""
    exit 1
fi

echo "📱 Building release APKs..."
echo ""

# Navigate to Flutter directory
cd "$FLUTTER_DIR"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build split APKs
echo "🔨 Building split APKs..."
flutter build apk --split-per-abi --release

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Copy and rename APKs
echo ""
echo "📁 Copying APKs to release directory..."

APK_DIR="$FLUTTER_DIR/build/app/outputs/flutter-apk"

cp "$APK_DIR/app-arm64-v8a-release.apk" "$OUTPUT_DIR/awsmgr-$VERSION-arm64-v8a.apk"
cp "$APK_DIR/app-armeabi-v7a-release.apk" "$OUTPUT_DIR/awsmgr-$VERSION-armeabi-v7a.apk"
cp "$APK_DIR/app-x86_64-release.apk" "$OUTPUT_DIR/awsmgr-$VERSION-x86_64.apk"

# Generate checksums
echo "🔒 Generating checksums..."
cd "$OUTPUT_DIR"
sha256sum *.apk > checksums-sha256.txt

echo ""
echo "============================================"
echo "  ✅ Build Complete!"
echo "============================================"
echo ""
echo "Release files are in: $OUTPUT_DIR"
echo ""
ls -lh "$OUTPUT_DIR"
echo ""
echo "Checksums:"
cat checksums-sha256.txt
echo ""
echo "============================================"
echo "  Next Steps:"
echo "============================================"
echo ""
echo "1. Test the APKs on a real device"
echo "2. Create a GitHub release with tag: $VERSION"
echo "3. Upload the APK files and checksums"
echo ""
