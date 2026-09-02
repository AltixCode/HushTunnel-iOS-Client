#!/bin/sh
set -e

echo "=== Xcode Cloud: ci_post_clone.sh started ==="

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "Repository Root: $REPO_ROOT"

# Install Go if not present in Xcode Cloud environment
if ! command -v go >/dev/null 2>&1; then
    echo "Installing Go..."
    brew install go
fi

export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"

echo "Installing sagernet gomobile & gobind..."
go install github.com/sagernet/gomobile/cmd/gomobile@latest
go install github.com/sagernet/gomobile/cmd/gobind@latest
gomobile init

echo "Building Libbox.xcframework from stable core..."
rm -rf /tmp/sing-box-build
git clone https://github.com/sagernet/sing-box.git /tmp/sing-box-build
cd /tmp/sing-box-build
git checkout bdd86c1

go run ./cmd/internal/build_libbox -target apple -platform ios

echo "Placing Libbox.xcframework at repository root..."
cp -r Libbox.xcframework "$REPO_ROOT/"
if [ -n "$CI_PRIMARY_REPOSITORY_PATH" ] && [ -d "$CI_PRIMARY_REPOSITORY_PATH" ]; then
    cp -r Libbox.xcframework "$CI_PRIMARY_REPOSITORY_PATH/" || true
fi

echo "=== Xcode Cloud: Libbox.xcframework prepared successfully ==="
