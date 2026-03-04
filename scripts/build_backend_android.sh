#!/bin/bash

# ============================================
# AethrOps - Build Backend for Android
# ============================================
# Builds Go backend library for Android architectures
# and copies them to Flutter jniLibs directory

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FLUTTER_DIR="$PROJECT_ROOT/awsmgr_ui"

echo "============================================"
echo "  AethrOps - Android Backend Builder"
echo "============================================"
echo ""

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

# Define architectures to build
ARCHS=("arm64-v8a" "armeabi-v7a" "x86_64")

echo ""
echo "🔨 Building Go backend library for Android..."
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
    go build -buildmode=c-shared -ldflags="-s -w" -o libbackend_$arch.so .

    if [ $? -ne 0 ]; then
        echo "❌ Failed to build Go backend for $arch"
        exit 1
    fi
    
    # Strip debug symbols to reduce size
    if [ "$arch" == "arm64-v8a" ]; then
        STRIP="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip"
    elif [ "$arch" == "armeabi-v7a" ]; then
        STRIP="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip"
    elif [ "$arch" == "x86_64" ]; then
        STRIP="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip"
    fi
    
    if [ -f "$STRIP" ]; then
        $STRIP libbackend_$arch.so
        echo "    ✓ Stripped debug symbols"
    fi
done

echo "  ✓ Go backend compiled for all architectures"

# Copy to Flutter project
echo ""
echo "📦 Copying libraries to Flutter Android project..."

for arch in "${ARCHS[@]}"; do
    TARGET_DIR="$FLUTTER_DIR/android/app/src/main/jniLibs/$arch"
    mkdir -p "$TARGET_DIR"
    cp libbackend_$arch.so "$TARGET_DIR/libbackend.so"
    echo "  ✓ Copied to $arch/"
    # Clean up
    rm libbackend_$arch.so
done

echo ""
echo "============================================"
echo "  ✅ Build Complete!"
echo "============================================"
echo ""
echo "Backend libraries copied to:"
echo "  $FLUTTER_DIR/android/app/src/main/jniLibs/"
echo ""
echo "Now you can build the APK with:"
echo "  cd awsmgr_ui"
echo "  flutter build apk"
echo ""
