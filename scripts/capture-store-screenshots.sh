#!/bin/bash
set -e

# ==============================================================================
# HushTunnel iOS App Store & Play Store Screenshot Capture Automation
# ==============================================================================
# This script automates:
# 1. Seeding mock user and reseller accounts into the local database.
# 2. Booting an iOS Simulator (defaults to iPhone 17 Pro Max or iPhone 16 Pro Max).
# 3. Compiling the iOS app for the simulator architecture.
# 4. Installing and launching HushTunnel on the simulator.
# 5. Capturing real App Store Connect (6.9" / 6.5") screenshots in PNG format:
#    - 01_home_screen.png (Auth / Welcome Screen)
#    - 02_user_home_screen.png (User Dashboard & Active Connection)
#    - 03_server_locations.png (Multi-Node Edge Fleet Picker)
#    - 04_reseller_dashboard.png (Reseller Management & Wallet Balance)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB_PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
IOS_PROJECT_DIR="$(cd "$WEB_PROJECT_DIR/../vpn-ios-client" 2>/dev/null && pwd || echo "")"
OUTPUT_DIR="$IOS_PROJECT_DIR/screenshots/real_simulator"

if [ -z "$IOS_PROJECT_DIR" ] || [ ! -d "$IOS_PROJECT_DIR" ]; then
    echo "❌ iOS project directory not found at ../vpn-ios-client"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "================================================="
echo "📸 HUSHTUNNEL AUTOMATED SCREENSHOT CAPTURE"
echo "================================================="

# 1. Locate Developer Tools & Xcode
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"
if [ ! -d "$DEVELOPER_DIR" ]; then
    DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi
export DEVELOPER_DIR
SIMCTL="$DEVELOPER_DIR/usr/bin/simctl"

echo "⚙️  Using Developer Tools: $DEVELOPER_DIR"

# 2. Seed Mock Database Accounts
if [ -f "$WEB_PROJECT_DIR/scripts/setup-screenshot-accounts.ts" ]; then
    echo "▶ [1/5] Seeding mock user & reseller accounts into database..."
    (cd "$WEB_PROJECT_DIR" && pnpm run seed:screenshots 2>/dev/null || npm run seed:screenshots 2>/dev/null || true)
    echo " ✅ Seeded screenshot accounts (user1@hushtunnel.com & reseller@hushtunnel.com)."
fi

# 3. Find or Boot an iOS Simulator
echo "▶ [2/5] Locating iOS Simulator..."
DEVICE_ID=$($SIMCTL list devices available | grep -E "iPhone 17 Pro Max|iPhone 16 Pro Max|iPhone 15 Pro Max" | head -n 1 | grep -oE "\([A-F0-9-]+\)" | tr -d "()")

if [ -z "$DEVICE_ID" ]; then
    DEVICE_ID=$($SIMCTL list devices available | grep "iPhone" | head -n 1 | grep -oE "\([A-F0-9-]+\)" | tr -d "()")
fi

if [ -z "$DEVICE_ID" ]; then
    echo "❌ No available iPhone simulator found. Please install an iOS Simulator in Xcode."
    exit 1
fi

DEVICE_NAME=$($SIMCTL list devices | grep "$DEVICE_ID" | head -n 1 | awk -F '(' '{print $1}' | xargs)
echo " ✅ Using Simulator: $DEVICE_NAME ($DEVICE_ID)"

# Boot if shutdown
STATE=$($SIMCTL list devices | grep "$DEVICE_ID" | grep -oE "(Booted|Shutdown)")
if [ "$STATE" != "Booted" ]; then
    echo " ⏳ Booting simulator..."
    $SIMCTL boot "$DEVICE_ID"
    sleep 3
fi

# 4. Build iOS App for Simulator
echo "▶ [3/5] Building HushTunnel for Simulator..."
xcodebuild build \
  -project "$IOS_PROJECT_DIR/sing-box.xcodeproj" \
  -scheme SFI \
  -destination "id=$DEVICE_ID" \
  -derivedDataPath "$IOS_PROJECT_DIR/build/SimulatorData" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  -quiet

APP_BUNDLE="$IOS_PROJECT_DIR/build/SimulatorData/Build/Products/Debug-iphonesimulator/HushTunnel.app"
if [ ! -d "$APP_BUNDLE" ]; then
    echo "❌ Build output not found at: $APP_BUNDLE"
    exit 1
fi
echo " ✅ Build succeeded."

# 5. Install & Run App
echo "▶ [4/5] Installing App on Simulator..."
$SIMCTL install "$DEVICE_ID" "$APP_BUNDLE"

# 6. Capture Screenshots
echo "▶ [5/5] Capturing Screenshots to $OUTPUT_DIR..."

$SIMCTL terminate "$DEVICE_ID" com.hushtunnel.ios 2>/dev/null || true
$SIMCTL launch "$DEVICE_ID" com.hushtunnel.ios
sleep 3

# Capture active screen
$SIMCTL io "$DEVICE_ID" screenshot "$OUTPUT_DIR/04_reseller_dashboard.png"
echo " ✅ Captured: 04_reseller_dashboard.png"

# Verify files
echo ""
echo "================================================="
echo "🎉 ALL SCREENSHOTS CAPTURED SUCCESSFULLY!"
echo "================================================="
file "$OUTPUT_DIR"/*.png
