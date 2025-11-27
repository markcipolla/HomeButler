#!/bin/bash

# HomeButler Build and Deploy Script
# Usage: ./build-and-deploy.sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="HomeButler"
SCHEME="HomeButler"
CONFIGURATION="Debug"
BUILD_DIR="$PROJECT_DIR/build"

echo "🏗️  Building $PROJECT_NAME..."

# Clean build folder
rm -rf "$BUILD_DIR"

# Build for device
xcodebuild \
    -project "$PROJECT_DIR/$PROJECT_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$BUILD_DIR" \
    -destination generic/platform=iOS \
    CODE_SIGN_IDENTITY="iPhone Developer" \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM="7UB7J68BJQ"

echo "✅ Build complete!"

# Find the .app bundle
APP_PATH=$(find "$BUILD_DIR" -name "$PROJECT_NAME.app" -type d | head -n 1)

if [ -z "$APP_PATH" ]; then
    echo "❌ Error: Could not find $PROJECT_NAME.app"
    exit 1
fi

echo "📱 App bundle: $APP_PATH"

# Check if ios-deploy is installed
if ! command -v ios-deploy &> /dev/null; then
    echo "⚠️  ios-deploy not found. Installing via Homebrew..."
    brew install ios-deploy
fi

# Detect connected device
echo "🔍 Detecting connected devices..."
DEVICE_ID=$(ios-deploy --detect --timeout 1 2>/dev/null | grep "Found" | awk '{print $2}' | head -n 1)

if [ -z "$DEVICE_ID" ]; then
    echo "❌ No iOS device detected. Please:"
    echo "   1. Connect your iPad via USB"
    echo "   2. Unlock the device"
    echo "   3. Trust this computer if prompted"
    exit 1
fi

echo "📱 Found device: $DEVICE_ID"

# Deploy to device
echo "🚀 Deploying to device..."
ios-deploy \
    --bundle "$APP_PATH" \
    --debug \
    --no-wifi

echo "✅ Deployment complete!"
echo "🎉 $PROJECT_NAME is now running on your iPad!"
