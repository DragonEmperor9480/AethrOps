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
OUTPUT_DIR="$PROJECT_ROOT/release/android"
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

# Check for Android NDK
if [ -z "$ANDROID_NDK_HOME" ]; then
    echo "⚠ ANDROID_NDK_HOME not set, attempting to auto-detect..."
    
    # Try common NDK locations
    POSSIBLE_PATHS=(
        "$HOME/Android/Sdk/ndk"
        "$ANDROID_HOME/ndk"
        "$ANDROID_SDK_ROOT/ndk"
    )
    
    for base_path in "${POSSIBLE_PATHS[@]}"; do
        if [ -d "$base_path" ]; then
            # Find the latest NDK version
            NDK_VERSION=$(ls -1 "$base_path" | sort -V | tail -n 1)
            if [ -n "$NDK_VERSION" ]; then
                export ANDROID_NDK_HOME="$base_path/$NDK_VERSION"
                echo "✓ Found NDK: $ANDROID_NDK_HOME"
                break
            fi
        fi
    done
    
    if [ -z "$ANDROID_NDK_HOME" ]; then
        echo "❌ Error: Could not find Android NDK"
        echo ""
        echo "Please install Android NDK or set ANDROID_NDK_HOME manually"
        exit 1
    fi
else
    echo "✓ Using NDK: $ANDROID_NDK_HOME"
fi

echo ""
# Define architectures to build
ARCHS=("arm64-v8a" "armeabi-v7a" "x86_64")

echo ""
echo "🔨 Step 1: Building Go backend library for multiple architectures..."
cd "$PROJECT_ROOT/backend_ffi"

for arch in "${ARCHS[@]}"; do
    echo "  • Building for $arch..."
    
    if [ "$arch" == "arm64-v8a" ]; then
        GO_ARCH="arm64"
        GO_ARM=""
        CC_COMPILER="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clang"
    elif [ "$arch" == "armeabi-v7a" ]; then
        GO_ARCH="arm"
        GO_ARM="7"
        CC_COMPILER="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi21-clang"
    elif [ "$arch" == "x86_64" ]; then
        GO_ARCH="amd64"
        GO_ARM=""
        CC_COMPILER="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/x86_64-linux-android21-clang"
    fi

    CGO_ENABLED=1 \
    GOOS=android \
    GOARCH=$GO_ARCH \
    GOARM=$GO_ARM \
    CC=$CC_COMPILER \
    go build -buildmode=c-shared -o libbackend_$arch.so main.go

    if [ $? -ne 0 ]; then
        echo "❌ Failed to build Go backend for $arch"
        exit 1
    fi
done

echo "  ✓ Go backend compiled for all architectures"

# Copy to Flutter project
echo ""
echo "📦 Step 2: Copying libraries to Flutter Android project..."

for arch in "${ARCHS[@]}"; do
    mkdir -p "$FLUTTER_DIR/android/app/src/main/jniLibs/$arch/"
    cp libbackend_$arch.so "$FLUTTER_DIR/android/app/src/main/jniLibs/$arch/libbackend.so"
    # Clean up
    rm libbackend_$arch.so
done

echo "✓ Libraries copied to jniLibs"

cd "$PROJECT_ROOT"

echo ""
echo "📱 Step 3: Building release APKs..."
echo ""

# Navigate to Flutter directory
cd "$FLUTTER_DIR"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build split APKs (signed)
echo "🔨 Building split APKs..."
flutter build apk --split-per-abi --release

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Copy and rename APKs
echo ""
echo "📁 Copying APKs to release directory..."

APK_DIR="$FLUTTER_DIR/build/app/outputs/flutter-apk"

cp "$APK_DIR/app-arm64-v8a-release.apk" "$OUTPUT_DIR/aws-manager-$VERSION-arm64-v8a.apk"
cp "$APK_DIR/app-armeabi-v7a-release.apk" "$OUTPUT_DIR/aws-manager-$VERSION-armeabi-v7a.apk"
cp "$APK_DIR/app-x86_64-release.apk" "$OUTPUT_DIR/aws-manager-$VERSION-x86_64.apk"

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
echo "✓ APKs are SIGNED with your keystore"
echo ""
echo "============================================"
echo "  Next Steps:"
echo "============================================"
echo ""
echo "1. Test the APKs on a real device"
echo "2. Create a GitHub release with tag: $VERSION"
echo "3. Upload the APK files and checksums"
echo ""
