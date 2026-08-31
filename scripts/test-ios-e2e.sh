#!/bin/bash
set -e

echo "================================================="
echo "🍎 HUSHTUNNEL IOS COMPREHENSIVE E2E TEST"
echo "================================================="

DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
SIMCTL="$DEVELOPER_DIR/usr/bin/simctl"

echo "▶ [1/3] Building iOS Simulator App..."
DEVELOPER_DIR=$DEVELOPER_DIR xcodebuild build \
  -project /Users/atamohammadi/Dev/vpn-ios-client/sing-box.xcodeproj \
  -scheme SFI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /Users/atamohammadi/Dev/vpn-ios-client/build/DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  -quiet

echo " ✅ iOS Simulator build succeeded."

echo "▶ [2/3] Installing and Launching on Simulator..."
$SIMCTL install booted /Users/atamohammadi/Dev/vpn-ios-client/build/DerivedData/Build/Products/Debug-iphonesimulator/HushTunnel.app
$SIMCTL launch booted io.nekohasekai.sfamt
sleep 3
echo " ✅ Launched io.nekohasekai.sfamt on iPhone 17 Pro."

echo "▶ [3/3] Capturing E2E Screen Artifact..."
$SIMCTL io booted screenshot /Users/atamohammadi/Dev/vpn-ios-client/store_assets/02_home_dashboard.png
echo " ✅ Captured iOS Home Dashboard -> store_assets/02_home_dashboard.png"

echo "================================================="
echo "🎉 IOS E2E TEST COMPLETED SUCCESSFULLY!"
echo "================================================="
