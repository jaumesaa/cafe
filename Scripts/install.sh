#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED="$ROOT/.build"
CONFIGURATION="${1:-Release}"

echo "Building cafe ($CONFIGURATION)…"
xcodebuild \
  -project "$ROOT/Cafe.xcodeproj" \
  -scheme Cafe \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED" \
  -destination "platform=macOS,arch=arm64" \
  build

APP="$DERIVED/Build/Products/$CONFIGURATION/cafe.app"
if [[ ! -d "$APP" ]]; then
  echo "Build succeeded but cafe.app was not found at $APP" >&2
  exit 1
fi

echo "Installing to /Applications/cafe.app"
rm -rf /Applications/Cafe.app /Applications/cafe.app
ditto "$APP" /Applications/cafe.app
echo "Done. Open Spotlight and type cafe, or run: open /Applications/cafe.app"
