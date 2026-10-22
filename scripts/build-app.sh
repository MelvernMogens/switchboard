#!/bin/bash
# Build Switchboard.app: release build -> .app bundle -> ad-hoc codesign.
# Usage: scripts/build-app.sh [--install]   (--install copies to /Applications and launches)
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Switchboard"
APP="build/Switchboard.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Switchboard"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

codesign --force --sign - --identifier com.melvern.switchboard "$APP"
echo "built $APP"

if [ "${1:-}" = "--install" ]; then
  pkill -x Switchboard || true
  rm -rf /Applications/Switchboard.app
  cp -R "$APP" /Applications/
  open /Applications/Switchboard.app
  echo "installed /Applications/Switchboard.app"
fi
