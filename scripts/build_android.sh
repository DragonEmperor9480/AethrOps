#!/bin/bash
# Build Android APK with embedded Go backend

set -e

echo "=========================================="
echo "Building AethrOps for Android"
echo "=========================================="

# Change to project root
cd "$(dirname "$0")/.."

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
        echo "Please install Android NDK or set ANDROID_NDK_HOME manually:"
        echo "  export ANDROID_NDK_HOME=~/Android/Sdk/ndk/29.0.13846066"
        echo ""
        echo "To install NDK:"
        echo "  Android Studio → SDK Manager → SDK Tools → NDK (Side by side)"
        exit 1
    fi
else
    echo "✓ Using NDK: $ANDROID_NDK_HOME"
fi

echo ""
# Define architectures to build
ARCHS=("arm64-v8a" "armeabi-v7a" "x86_64")

echo ""
echo "Step 1: Building Go backend library for multiple architectures..."
cd backend_ffi

for arch in "${ARCHS[@]}"; do
    echo "  Building for $arch..."
    
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

echo "✓ Go backend compiled for all architectures"

echo ""
echo "Step 2: Copying libraries to Flutter Android project..."

for arch in "${ARCHS[@]}"; do
    mkdir -p ../awsmgr_ui/android/app/src/main/jniLibs/$arch/
    cp libbackend_$arch.so ../awsmgr_ui/android/app/src/main/jniLibs/$arch/libbackend.so
    # Clean up
    rm libbackend_$arch.so
done

echo "✓ Libraries copied to jniLibs"

cd ..

echo ""
echo "Step 3: Building Flutter Android APK..."
cd awsmgr_ui

flutter clean
flutter pub get
flutter build apk --split-per-abi --release

if [ $? -ne 0 ]; then
    echo "❌ Failed to build Flutter APK"
    exit 1
fi

echo ""
echo "=========================================="
echo "✓ Build Complete!"
echo "=========================================="
echo "APK location: awsmgr_ui/build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "To install on device:"
echo "  flutter install"
echo "or"
echo "  adb install build/app/outputs/flutter-apk/app-release.apk"
