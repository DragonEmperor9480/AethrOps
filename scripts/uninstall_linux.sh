#!/bin/bash
# Uninstall AethrOps from Linux

APP_NAME="AethrOps"
BINARY_NAME="aethrops"
INSTALL_DIR="$HOME/.local/share/aethrops"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/512x512/apps"
DATA_DIR="$HOME/.aethrops"

echo "=========================================="
echo "Uninstalling $APP_NAME"
echo "=========================================="

# Check if installed
if [ ! -d "$INSTALL_DIR" ]; then
    echo "❌ $APP_NAME is not installed"
    echo "Installation directory not found: $INSTALL_DIR"
    exit 1
fi

# Confirm uninstallation
echo ""
echo "This will remove:"
echo "  - Application files: $INSTALL_DIR"
echo "  - Launcher: $BIN_DIR/$BINARY_NAME"
echo "  - Desktop entry: $DESKTOP_DIR/aethrops.desktop"
echo "  - Icon: $ICON_DIR/aethrops.png"
echo ""
read -p "Do you want to continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled"
    exit 0
fi

# Stop any running instances
echo ""
echo "Step 1: Stopping running instances..."
pkill -f "$INSTALL_DIR/aethrops" 2>/dev/null || true
pkill -f "$INSTALL_DIR/aethrops_core" 2>/dev/null || true
sleep 1
echo "✓ Processes stopped"

# Remove application files
echo ""
echo "Step 2: Removing application files..."
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    echo "✓ Removed $INSTALL_DIR"
fi

# Remove launcher
echo ""
echo "Step 3: Removing launcher..."
if [ -f "$BIN_DIR/$BINARY_NAME" ]; then
    rm "$BIN_DIR/$BINARY_NAME"
    echo "✓ Removed $BIN_DIR/$BINARY_NAME"
fi

# Remove desktop entry
echo ""
echo "Step 4: Removing desktop entry..."
if [ -f "$DESKTOP_DIR/aethrops.desktop" ]; then
    rm "$DESKTOP_DIR/aethrops.desktop"
    echo "✓ Removed desktop entry"
fi

# Remove icon
echo ""
echo "Step 5: Removing icon..."
if [ -f "$ICON_DIR/aethrops.png" ]; then
    rm "$ICON_DIR/aethrops.png"
    echo "✓ Removed icon"
fi
if [ -f "$ICON_DIR/aethrops.svg" ]; then
    rm "$ICON_DIR/aethrops.svg"
    echo "✓ Removed old SVG icon"
fi

# Update desktop database
echo ""
echo "Step 6: Updating desktop database..."
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
fi

if command -v gtk-update-icon-cache &> /dev/null; then
    gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
fi
echo "✓ Desktop database updated"

# Ask about user data
echo ""
echo "=========================================="
echo "User Data"
echo "=========================================="
echo ""
echo "Do you want to remove user data?"
echo "This includes:"
echo "  - AWS credentials (stored in secure storage)"
echo "  - Database: $DATA_DIR"
echo ""
read -p "Remove user data? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -d "$DATA_DIR" ]; then
        rm -rf "$DATA_DIR"
        echo "✓ Removed user data"
    else
        echo "ℹ No user data found"
    fi
else
    echo "ℹ User data preserved"
fi

echo ""
echo "=========================================="
echo "✓ Uninstallation Complete!"
echo "=========================================="
echo ""
echo "$APP_NAME has been removed from your system."
