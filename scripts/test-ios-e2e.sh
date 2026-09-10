#!/bin/bash
set -e

echo "================================================="
echo "🍎 HUSHTUNNEL IOS COMPREHENSIVE E2E TEST"
echo "================================================="

DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
SIMCTL="$DEVELOPER_DIR/usr/bin/simctl"

echo "▶ [1/5] Building iOS Simulator App..."
DEVELOPER_DIR=$DEVELOPER_DIR xcodebuild build \
  -project /Users/atamohammadi/Dev/vpn-ios-client/sing-box.xcodeproj \
  -scheme SFI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /Users/atamohammadi/Dev/vpn-ios-client/build/DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  -quiet

echo " ✅ iOS Simulator build succeeded."

echo "▶ [2/5] Verifying guest configuration imports are not registered..."
BUILT_INFO=/Users/atamohammadi/Dev/vpn-ios-client/build/DerivedData/Build/Products/Debug-iphonesimulator/HushTunnel.app/Info.plist
if /usr/libexec/PlistBuddy -c 'Print :CFBundleURLTypes' "$BUILT_INFO" >/dev/null 2>&1 || \
   /usr/libexec/PlistBuddy -c 'Print :CFBundleDocumentTypes' "$BUILT_INFO" >/dev/null 2>&1; then
  echo "ERROR: The branded iOS app still registers a guest profile URL or document importer." >&2
  exit 1
fi
echo " ✅ Guest URL and document profile imports are not registered."

echo "▶ [3/5] Installing and Launching on Simulator..."
$SIMCTL install booted /Users/atamohammadi/Dev/vpn-ios-client/build/DerivedData/Build/Products/Debug-iphonesimulator/HushTunnel.app
$SIMCTL launch booted com.hushtunnel.ios --mock-session --reset-vpn-disclosure -app_language en
sleep 3
echo " ✅ Launched com.hushtunnel.ios on iPhone 17 Pro."

echo "▶ [4/5] Capturing VPN Disclosure Artifact..."
$SIMCTL io booted screenshot /Users/atamohammadi/Dev/vpn-ios-client/store_assets/03_vpn_disclosure.png
echo " ✅ Captured VPN disclosure -> store_assets/03_vpn_disclosure.png"

echo "▶ [5/5] Running Store Compliance UI Test..."
DEVELOPER_DIR=$DEVELOPER_DIR PATH="$DEVELOPER_DIR/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin" xcodebuild test \
  -project /Users/atamohammadi/Dev/vpn-ios-client/sing-box.xcodeproj \
  -scheme SFI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  -only-testing:SFIUITests/StoreComplianceTests \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  -quiet
echo " ✅ Disclosure, legal links, store management, and guarded deletion UI verified."

echo "================================================="
echo "🎉 IOS E2E TEST COMPLETED SUCCESSFULLY!"
echo "================================================="
