#!/bin/bash
# Build Debian package for AWS Manager

set -e

echo "=========================================="
echo "Building AWS Manager Debian Package"
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
    VERSION="0.1.0-preview-beta-1"
fi

# Sanitize version for Debian (replace spaces, ensure starts with digit)
VERSION=$(echo "$VERSION" | tr ' ' '-' | tr '_' '-')
if [[ ! "$VERSION" =~ ^[0-9] ]]; then
    VERSION="0.0.0-$VERSION"
fi

echo "Version: $VERSION"

PACKAGE_NAME="aws-manager"
ARCH="amd64"
DEB_DIR="$PROJECT_ROOT/build/debian"
PACKAGE_DIR="$DEB_DIR/${PACKAGE_NAME}_${VERSION}_${ARCH}"
RELEASE_DIR="$PROJECT_ROOT/release/linux"

echo "Package: $PACKAGE_NAME"
echo "Version: $VERSION"
echo "Architecture: $ARCH"
echo ""

# Clean previous builds
echo "Step 1: Cleaning previous builds..."
rm -rf "$DEB_DIR"
mkdir -p "$PACKAGE_DIR"

# Build the application
echo ""
echo "Step 2: Building application..."
bash scripts/build_linux.sh

if [ $? -ne 0 ]; then
    echo "❌ Failed to build application"
    exit 1
fi

# Create Debian package structure
echo ""
echo "Step 3: Creating Debian package structure..."

# Create directories
mkdir -p "$PACKAGE_DIR/DEBIAN"
mkdir -p "$PACKAGE_DIR/opt/awsmgr"
mkdir -p "$PACKAGE_DIR/usr/share/applications"
mkdir -p "$PACKAGE_DIR/usr/share/icons/hicolor/256x256/apps"
mkdir -p "$PACKAGE_DIR/usr/bin"

# Copy application files
echo "Copying application files..."
cp -r awsmgr_ui/build/linux/x64/release/bundle/* "$PACKAGE_DIR/opt/awsmgr/"

# Create launcher script
echo "Creating launcher script..."
cat > "$PACKAGE_DIR/usr/bin/awsmgr" << 'EOF'
#!/bin/bash
cd /opt/awsmgr
exec ./awsmgr "$@"
EOF
chmod +x "$PACKAGE_DIR/usr/bin/awsmgr"

# Create desktop entry
echo "Creating desktop entry..."
cat > "$PACKAGE_DIR/usr/share/applications/awsmgr.desktop" << EOF
[Desktop Entry]
Name=AWS Manager
Comment=AWS Resource Management Tool
Exec=/usr/bin/awsmgr
Icon=awsmgr
Terminal=false
Type=Application
Categories=Development;Utility;
Keywords=aws;cloud;management;iam;s3;lambda;
StartupWMClass=awsmgr
EOF

# Copy or create icon (if you have one)
if [ -f "awsmgr_ui/assets/icon.png" ]; then
    cp "awsmgr_ui/assets/icon.png" "$PACKAGE_DIR/usr/share/icons/hicolor/256x256/apps/awsmgr.png"
elif [ -f "awsmgr_ui/linux/flutter/generated_plugin_registrant.cc" ]; then
    # Create a simple placeholder icon if none exists
    echo "Note: No icon found, package will use default icon"
fi

# Create control file
echo "Creating control file..."
INSTALLED_SIZE=$(du -sk "$PACKAGE_DIR/opt/awsmgr" | cut -f1)

cat > "$PACKAGE_DIR/DEBIAN/control" << EOF
Package: $PACKAGE_NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: $ARCH
Installed-Size: $INSTALLED_SIZE
Depends: libc6 (>= 2.31), libstdc++6 (>= 10), libglib2.0-0 (>= 2.64), libgtk-3-0 (>= 3.24)
Maintainer: DragonEmperor9480 <amruteshnaregal1234@gmail.com>
Homepage: https://github.com/DragonEmperor9480/aws-manager
Description: AWS Resource Management Tool
 A comprehensive desktop application for managing AWS resources including
 IAM users, groups, policies, S3 buckets, Lambda functions, and more.
 .
 Features:
  - IAM user and group management
  - S3 bucket browser with file operations
  - Lambda function management
  - CloudWatch logs viewer
  - Email notifications for credentials
  - MFA device configuration
EOF

# Create postinst script
echo "Creating postinst script..."
cat > "$PACKAGE_DIR/DEBIAN/postinst" << 'EOF'
#!/bin/bash
set -e

# Update desktop database
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q
fi

# Update icon cache
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi

echo "AWS Manager installed successfully!"
echo "You can launch it from your application menu or run 'awsmgr' in terminal."

exit 0
EOF
chmod +x "$PACKAGE_DIR/DEBIAN/postinst"

# Create prerm script
echo "Creating prerm script..."
cat > "$PACKAGE_DIR/DEBIAN/prerm" << 'EOF'
#!/bin/bash
set -e

# Stop any running instances
pkill -f "/opt/awsmgr/awsmgr" || true

exit 0
EOF
chmod +x "$PACKAGE_DIR/DEBIAN/prerm"

# Create postrm script
echo "Creating postrm script..."
cat > "$PACKAGE_DIR/DEBIAN/postrm" << 'EOF'
#!/bin/bash
set -e

if [ "$1" = "purge" ]; then
    # Remove user data if purging
    rm -rf ~/.config/awsmgr || true
    rm -rf ~/.local/share/awsmgr || true
fi

# Update desktop database
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q
fi

# Update icon cache
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi

exit 0
EOF
chmod +x "$PACKAGE_DIR/DEBIAN/postrm"

# Create copyright file
echo "Creating copyright file..."
mkdir -p "$PACKAGE_DIR/usr/share/doc/$PACKAGE_NAME"
cat > "$PACKAGE_DIR/usr/share/doc/$PACKAGE_NAME/copyright" << EOF
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: AWS Manager
Source: https://github.com/DragonEmperor9480/aws-manager

Files: *
Copyright: $(date +%Y) AWS Manager Team
License: MIT
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 .
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 .
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
EOF

# Create changelog
echo "Creating changelog..."
cat > "$PACKAGE_DIR/usr/share/doc/$PACKAGE_NAME/changelog.Debian" << EOF
$PACKAGE_NAME ($VERSION) unstable; urgency=medium

  * Release version $VERSION
  * IAM user and group management
  * S3 bucket browser with versioning support
  * Lambda function management
  * CloudWatch logs integration
  * Email notification system
  * MFA device configuration

 -- AWS Manager Team <awsmgr@example.com>  $(date -R)
EOF
gzip -9 -n "$PACKAGE_DIR/usr/share/doc/$PACKAGE_NAME/changelog.Debian"

# Build the package
echo ""
echo "Step 4: Building Debian package..."
cd "$DEB_DIR"
dpkg-deb --build --root-owner-group "${PACKAGE_NAME}_${VERSION}_${ARCH}"

if [ $? -ne 0 ]; then
    echo "❌ Failed to build Debian package"
    exit 1
fi

# Move to release directory
mkdir -p "$RELEASE_DIR"
mv "${PACKAGE_NAME}_${VERSION}_${ARCH}.deb" "$RELEASE_DIR/"

# Verify the package
echo ""
echo "Step 5: Verifying package..."
dpkg-deb --info "$RELEASE_DIR/${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
echo ""
dpkg-deb --contents "$RELEASE_DIR/${PACKAGE_NAME}_${VERSION}_${ARCH}.deb" | head -20
echo "... (showing first 20 files)"

echo ""
echo "=========================================="
echo "✓ Debian Package Build Complete!"
echo "=========================================="
echo "Package: $RELEASE_DIR/${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
echo "Size: $(du -h "$RELEASE_DIR/${PACKAGE_NAME}_${VERSION}_${ARCH}.deb" | cut -f1)"
echo ""
echo "To install:"
echo "  sudo dpkg -i $RELEASE_DIR/${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
echo "  sudo apt-get install -f  # Install dependencies if needed"
echo ""
echo "To uninstall:"
echo "  sudo apt-get remove $PACKAGE_NAME"
echo ""
echo "To purge (remove with config):"
echo "  sudo apt-get purge $PACKAGE_NAME"
echo ""
