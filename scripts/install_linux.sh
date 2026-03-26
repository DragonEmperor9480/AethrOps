#!/bin/bash
# Install AethrOps on Linux

set -e

APP_NAME="AethrOps"
BINARY_NAME="aethrops"
INSTALL_DIR="$HOME/.local/share/aethrops"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/512x512/apps"

echo "=========================================="
echo "Installing $APP_NAME"
echo "=========================================="

# Change to project root
cd "$(dirname "$0")/.."

# Step 1: Build Go backend
echo ""
echo "Step 1: Building Go backend..."
cd backend
go build -o aethrops_core main.go
chmod +x aethrops_core
cd ..
echo "✓ Backend compiled"

# Step 2: Build Flutter app
echo ""
echo "Step 2: Building Flutter application..."
cd awsmgr_ui
flutter clean
flutter pub get
flutter build linux --release

if [ $? -ne 0 ]; then
    echo "❌ Failed to build Flutter app"
    exit 1
fi
echo "✓ Flutter app built"

# Step 3: Copy backend to bundle
echo ""
echo "Step 3: Bundling backend with application..."
cp ../backend/aethrops_core build/linux/x64/release/bundle/
chmod +x build/linux/x64/release/bundle/aethrops_core
echo "✓ Backend bundled"

cd ..

# Step 4: Create installation directory
echo ""
echo "Step 4: Creating installation directory..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$BIN_DIR"
mkdir -p "$DESKTOP_DIR"
mkdir -p "$ICON_DIR"

# Step 5: Copy application files
echo ""
echo "Step 5: Installing application files..."
cp -r awsmgr_ui/build/linux/x64/release/bundle/* "$INSTALL_DIR/"
echo "✓ Files copied to $INSTALL_DIR"

# Step 6: Create launcher script
echo ""
echo "Step 6: Creating launcher..."
cat > "$BIN_DIR/$BINARY_NAME" << 'EOF'
#!/bin/bash
# AethrOps Launcher
cd "$HOME/.local/share/aethrops"
./aethrops "$@"
EOF

chmod +x "$BIN_DIR/$BINARY_NAME"
echo "✓ Launcher created at $BIN_DIR/$BINARY_NAME"

# Step 7: Install application icon
echo ""
echo "Step 7: Installing application icon..."
if [ -f "awsmgr_ui/linux/icon.png" ]; then
    cp awsmgr_ui/linux/icon.png "$ICON_DIR/aethrops.png"
    echo "✓ Icon installed"
else
    echo "⚠ Warning: Icon not found at awsmgr_ui/linux/icon.png"
    echo "  The app will use the default icon"
fi

# Step 8: Create desktop entry
echo ""
echo "Step 8: Creating desktop entry..."
cat > "$DESKTOP_DIR/aethrops.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$APP_NAME
Comment=Manage your AWS infrastructure
Exec=$BIN_DIR/$BINARY_NAME
Icon=aethrops
Terminal=false
Categories=Development;Utility;
Keywords=aws;cloud;s3;iam;management;
StartupNotify=true
EOF

chmod +x "$DESKTOP_DIR/aethrops.desktop"
echo "✓ Desktop entry created"

# Step 9: Update desktop database
echo ""
echo "Step 9: Updating desktop database..."
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
fi

if command -v gtk-update-icon-cache &> /dev/null; then
    gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
fi

echo ""
echo "=========================================="
echo "✓ Installation Complete!"
echo "=========================================="
echo ""
echo "Installation Details:"
echo "  Application: $INSTALL_DIR"
echo "  Launcher: $BIN_DIR/$BINARY_NAME"
echo "  Desktop Entry: $DESKTOP_DIR/aethrops.desktop"
echo ""
echo "You can now:"
echo "  1. Run from terminal: $BINARY_NAME"
echo "  2. Launch from application menu: Search for '$APP_NAME'"
echo "  3. Add $BIN_DIR to your PATH if not already added"
echo ""
echo "To uninstall, run:"
echo "  rm -rf $INSTALL_DIR"
echo "  rm $BIN_DIR/$BINARY_NAME"
echo "  rm $DESKTOP_DIR/aethrops.desktop"
echo "  rm $ICON_DIR/aethrops.svg"
