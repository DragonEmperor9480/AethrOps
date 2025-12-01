#!/bin/bash
# Build AppImage for AWS Manager
# AppImage is a universal Linux package format that works on most distributions

set -e

echo "=========================================="
echo "Building AWS Manager AppImage"
echo "=========================================="

# Change to project root
cd "$(dirname "$0")/.."
PROJECT_ROOT=$(pwd)

# Extract version from pubspec.yaml
VERSION=$(grep "^version:" awsmgr_ui/pubspec.yaml | awk '{print $2}' | cut -d'+' -f1)
if [ -z "$VERSION" ]; then
    VERSION="1.0.0"
fi

APP_NAME="AWS_Manager"
APPIMAGE_NAME="AWS_Manager-${VERSION}-x86_64.AppImage"
APPDIR="$PROJECT_ROOT/build/appimage/AWS_Manager.AppDir"

echo "App: $APP_NAME"
echo "Version: $VERSION"
echo ""

# Check for required tools
echo "Step 1: Checking required tools..."
if ! command -v wget &> /dev/null; then
    echo "❌ wget is required but not installed. Install it with: sudo apt install wget"
    exit 1
fi

# Clean previous builds
echo ""
echo "Step 2: Cleaning previous builds..."
rm -rf "$PROJECT_ROOT/build/appimage"
mkdir -p "$APPDIR"

# Build the application
echo ""
echo "Step 3: Building application..."
bash scripts/build_linux.sh

if [ $? -ne 0 ]; then
    echo "❌ Failed to build application"
    exit 1
fi

# Create AppDir structure
echo ""
echo "Step 4: Creating AppImage directory structure..."

# Copy application files
echo "Copying application files..."
cp -r awsmgr_ui/build/linux/x64/release/bundle/* "$APPDIR/"

# Create AppRun script (entry point for AppImage)
echo "Creating AppRun script..."
cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/bash
# AppRun script for AWS Manager

# Get the directory where this AppImage is mounted
APPDIR="$(dirname "$(readlink -f "$0")")"

# Set library path to include bundled libraries
export LD_LIBRARY_PATH="$APPDIR/lib:$LD_LIBRARY_PATH"

# Change to app directory
cd "$APPDIR"

# Start the backend in background
./awsmgr_backend &
BACKEND_PID=$!

# Function to cleanup on exit
cleanup() {
    kill $BACKEND_PID 2>/dev/null || true
}
trap cleanup EXIT

# Run the Flutter app
exec "$APPDIR/awsmgr" "$@"
EOF
chmod +x "$APPDIR/AppRun"

# Create desktop file
echo "Creating desktop entry..."
cat > "$APPDIR/awsmgr.desktop" << EOF
[Desktop Entry]
Name=AWS Manager
Comment=AWS Resource Management Tool
Exec=awsmgr
Icon=awsmgr
Terminal=false
Type=Application
Categories=Development;Utility;
Keywords=aws;cloud;management;iam;s3;lambda;
StartupWMClass=awsmgr
X-AppImage-Version=$VERSION
EOF

# Create or copy icon
echo "Setting up icon..."
ICON_CREATED=false

# Try to find existing icon
if [ -f "awsmgr_ui/assets/icon.png" ]; then
    cp "awsmgr_ui/assets/icon.png" "$APPDIR/awsmgr.png"
    ICON_CREATED=true
elif [ -f "awsmgr_ui/linux/awsmgr.png" ]; then
    cp "awsmgr_ui/linux/awsmgr.png" "$APPDIR/awsmgr.png"
    ICON_CREATED=true
fi

# Create a simple placeholder icon if none exists
if [ "$ICON_CREATED" = false ]; then
    echo "Note: No icon found, creating placeholder..."
    # Create a simple 256x256 PNG with ImageMagick if available
    if command -v convert &> /dev/null; then
        convert -size 256x256 xc:transparent \
                -fill '#6B46C1' -draw 'circle 128,128 128,20' \
                -fill white -pointsize 80 -gravity center -annotate +0+0 'AWS' \
                "$APPDIR/awsmgr.png"
    else
        echo "⚠️  ImageMagick not found. AppImage will use default icon."
        echo "   Install ImageMagick or add icon.png to awsmgr_ui/assets/"
        # Create a minimal 1x1 transparent PNG as fallback
        echo -n "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==" | base64 -d > "$APPDIR/awsmgr.png"
    fi
fi

# Create .DirIcon symlink (required for AppImage)
ln -sf awsmgr.png "$APPDIR/.DirIcon"

# Download appimagetool if not present
APPIMAGETOOL="$PROJECT_ROOT/build/appimage/appimagetool-x86_64.AppImage"
if [ ! -f "$APPIMAGETOOL" ]; then
    echo ""
    echo "Step 5: Downloading appimagetool..."
    wget -q --show-progress -O "$APPIMAGETOOL" \
        "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
    chmod +x "$APPIMAGETOOL"
else
    echo ""
    echo "Step 5: Using existing appimagetool..."
fi

# Build the AppImage
echo ""
echo "Step 6: Building AppImage..."
cd "$PROJECT_ROOT/build/appimage"

# Set ARCH environment variable (required by appimagetool)
export ARCH=x86_64

# Build AppImage
"$APPIMAGETOOL" --no-appstream "AWS_Manager.AppDir" "$APPIMAGE_NAME"

if [ $? -ne 0 ]; then
    echo "❌ Failed to build AppImage"
    exit 1
fi

# Make it executable
chmod +x "$APPIMAGE_NAME"

# Get file size
SIZE=$(du -h "$APPIMAGE_NAME" | cut -f1)

echo ""
echo "=========================================="
echo "✓ AppImage Build Complete!"
echo "=========================================="
echo "AppImage: $PROJECT_ROOT/build/appimage/$APPIMAGE_NAME"
echo "Size: $SIZE"
echo ""
echo "To run:"
echo "  ./$APPIMAGE_NAME"
echo ""
echo "To install (optional):"
echo "  mv $APPIMAGE_NAME ~/.local/bin/awsmgr"
echo "  # Or move to /usr/local/bin for system-wide installation"
echo ""
echo "The AppImage is portable and can be:"
echo "  - Copied to any Linux system"
echo "  - Run without installation"
echo "  - Integrated with AppImageLauncher for desktop integration"
echo ""
