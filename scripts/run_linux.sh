#!/bin/bash
# Run AethrOps on Linux (development mode)

set -e

echo "=========================================="
echo "Running AethrOps on Linux"
echo "=========================================="

# Change to project root
cd "$(dirname "$0")/.."

echo ""
echo "Step 1: Building Go backend..."
cd backend
go build -o aethrops_core main.go
chmod +x aethrops_core
cd ..
echo "✓ Backend compiled"

echo ""
echo "Step 2: Starting Flutter app..."
cd awsmgr_ui

# The Linux build (linux/CMakeLists.txt) copies backend/aethrops_core into the
# bundle itself, so Flutter runs in the foreground and the r/R hot reload keys work.
exec flutter run -d linux
