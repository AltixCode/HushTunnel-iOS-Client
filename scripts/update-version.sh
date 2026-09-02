#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMIT_COUNT=$(git -C "$DIR" rev-list --count HEAD 2>/dev/null || echo 500)
BUILD_NUMBER=$((COMMIT_COUNT + 1))
MARKETING_VER="1.0.0"

echo "Syncing iOS versions: MARKETING_VERSION=$MARKETING_VER, CURRENT_PROJECT_VERSION=$BUILD_NUMBER"

node -e "
const fs = require('fs');
const file = '$DIR/sing-box.xcodeproj/project.pbxproj';
let content = fs.readFileSync(file, 'utf8');
content = content.replace(/MARKETING_VERSION = [^;]+;/g, 'MARKETING_VERSION = $MARKETING_VER;');
content = content.replace(/CURRENT_PROJECT_VERSION = [^;]+;/g, 'CURRENT_PROJECT_VERSION = $BUILD_NUMBER;');
fs.writeFileSync(file, content, 'utf8');
"
