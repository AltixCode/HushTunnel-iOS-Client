#!/bin/bash
set -e

echo "================================================="
echo "🍎 HUSHTUNNEL IOS COMPREHENSIVE E2E TEST"
echo "================================================="

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVELOPER_DIR="$(xcode-select -p 2>/dev/null || echo '/Applications/Xcode.app/Contents/Developer')"
SIMCTL="xcrun simctl"

# Detect booted simulator or default to iPhone 18 Pro
BOOTED_DEVICE_ID=$($SIMCTL list devices | grep -m 1 "Booted" | awk -F '[()]' '{print $2}')
if [ -n "$BOOTED_DEVICE_ID" ]; then
  DESTINATION="platform=iOS Simulator,id=$BOOTED_DEVICE_ID"
else
  DESTINATION="platform=iOS Simulator,name=iPhone 18 Pro"
fi

echo "▶ [1/5] Building iOS Simulator App..."
DEVELOPER_DIR=$DEVELOPER_DIR xcodebuild build \
  -project "$REPO_ROOT/sing-box.xcodeproj" \
  -scheme SFI \
  -destination "$DESTINATION" \
  -derivedDataPath "$REPO_ROOT/build/DerivedData" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  -quiet

echo " ✅ iOS Simulator build succeeded."

echo "▶ [2/5] Verifying guest configuration imports are not registered..."
BUILT_INFO="$REPO_ROOT/build/DerivedData/Build/Products/Debug-iphonesimulator/HushTunnel.app/Info.plist"
if /usr/libexec/PlistBuddy -c 'Print :CFBundleURLTypes' "$BUILT_INFO" >/dev/null 2>&1 || \
   /usr/libexec/PlistBuddy -c 'Print :CFBundleDocumentTypes' "$BUILT_INFO" >/dev/null 2>&1; then
  echo "ERROR: The branded iOS app still registers a guest profile URL or document importer." >&2
  exit 1
fi
echo " ✅ Guest URL and document profile imports are not registered."

echo "▶ [3/5] Installing and Launching on Simulator..."
$SIMCTL install booted "$REPO_ROOT/build/DerivedData/Build/Products/Debug-iphonesimulator/HushTunnel.app"
$SIMCTL launch booted com.hushtunnel.ios --mock-session --reset-vpn-disclosure -app_language en
sleep 3
echo " ✅ Launched com.hushtunnel.ios on simulator."

echo "▶ [4/5] Capturing VPN Disclosure Artifact..."
mkdir -p "$REPO_ROOT/store_assets"
$SIMCTL io booted screenshot "$REPO_ROOT/store_assets/03_vpn_disclosure.png"
echo " ✅ Captured VPN disclosure -> store_assets/03_vpn_disclosure.png"

echo "▶ [5/5] Running Store Compliance UI Test..."
DEVELOPER_DIR=$DEVELOPER_DIR PATH="$DEVELOPER_DIR/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin" xcodebuild test \
  -project "$REPO_ROOT/sing-box.xcodeproj" \
  -scheme SFI \
  -destination "$DESTINATION" \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  -only-testing:SFIUITests/StoreComplianceTests \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  -quiet
echo " ✅ Disclosure, legal links, store management, and guarded deletion UI verified."

echo "================================================="
echo "🎉 IOS E2E TEST COMPLETED SUCCESSFULLY!"
echo "================================================="
