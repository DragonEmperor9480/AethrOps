#!/bin/bash
# Build a release APK (with a freshly built Go backend) and install it on the
# connected Android phone, keeping the app's data.
#
# Usage: ./scripts/install_android.sh [--skip-backend] [--wipe]
#   --skip-backend  reuse the libbackend.so files already in jniLibs
#   --wipe          if the installed app is signed with a different key,
#                   uninstall it first. This DELETES its data on the phone
#                   (saved AWS accounts, secrets, PIN, settings).
#
# With several devices connected, pick one with ANDROID_SERIAL=<serial>
# (see `adb devices`).

set -e

SKIP_BACKEND=0
WIPE=0
for arg in "$@"; do
    case "$arg" in
        --skip-backend) SKIP_BACKEND=1 ;;
        --wipe) WIPE=1 ;;
        -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
        *) echo "❌ Unknown option: $arg"; exit 1 ;;
    esac
done

cd "$(dirname "$0")/.."
ROOT=$(pwd)
PACKAGE=com.amrut.aethrops
APK="$ROOT/awsmgr_ui/build/app/outputs/flutter-apk/app-release.apk"

# Pick the device before the long build, so a missing phone fails fast
if [ -z "$ANDROID_SERIAL" ]; then
    DEVICES=$(adb devices | awk 'NR > 1 && $2 == "device" {print $1}')
    COUNT=$(echo "$DEVICES" | grep -c . || true)
    if [ "$COUNT" -eq 0 ]; then
        echo "❌ No Android device connected (check USB debugging and 'adb devices')"
        exit 1
    elif [ "$COUNT" -gt 1 ]; then
        echo "❌ Several devices connected; choose one with ANDROID_SERIAL=<serial>:"
        echo "$DEVICES"
        exit 1
    fi
    export ANDROID_SERIAL="$DEVICES"
fi
echo "✓ Device: $ANDROID_SERIAL"

if [ "$SKIP_BACKEND" -eq 0 ]; then
    echo ""
    echo "Step 1: Building the Go backend for Android..."
    "$ROOT/scripts/build_backend_android.sh"
else
    echo ""
    echo "Step 1: Skipped (reusing the backend libraries in jniLibs)"
fi

echo ""
echo "Step 2: Building the release APK..."
cd "$ROOT/awsmgr_ui"
flutter build apk --release

echo ""
echo "Step 3: Installing on $ANDROID_SERIAL (keeping app data)..."
set +e
OUTPUT=$(adb install -r "$APK" 2>&1)
STATUS=$?
set -e
echo "$OUTPUT" | tail -n 2

if [ "$STATUS" -ne 0 ]; then
    if echo "$OUTPUT" | grep -q "INSTALL_FAILED_UPDATE_INCOMPATIBLE"; then
        if [ "$WIPE" -eq 1 ]; then
            echo ""
            echo "⚠ The installed app has a different signature; uninstalling it (its data is deleted)..."
            adb uninstall "$PACKAGE"
            adb install "$APK"
        else
            echo ""
            echo "❌ The installed app is signed with a different key, so it cannot be updated."
            echo "   Rerun with --wipe to uninstall it first. That deletes its data on the"
            echo "   phone (saved AWS accounts, secrets, PIN, settings)."
            exit 1
        fi
    else
        exit "$STATUS"
    fi
fi

echo ""
echo "✓ Installed. Starting the app..."
adb shell monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || true
