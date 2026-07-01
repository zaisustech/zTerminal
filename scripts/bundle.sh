#!/usr/bin/env bash
# Build zTerminal in release mode and wrap the binary into a launchable .app.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/zTerminal.app"
BIN_DIR="$APP/Contents/MacOS"
RES_DIR="$APP/Contents/Resources"

echo "▸ swift build -c release"
swift build -c release --package-path "$ROOT"
BIN="$(swift build -c release --package-path "$ROOT" --show-bin-path)/zTerminal"

echo "▸ Assembling $APP"
rm -rf "$APP"
mkdir -p "$BIN_DIR" "$RES_DIR"
cp "$BIN" "$BIN_DIR/zTerminal"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
[ -f "$ROOT/Resources/AppIcon.icns" ] && cp "$ROOT/Resources/AppIcon.icns" "$RES_DIR/AppIcon.icns"
[ -d "$ROOT/Resources/Fonts" ] && cp "$ROOT/Resources/Fonts/"*.ttf "$RES_DIR/" 2>/dev/null || true

# Register the bundle with Launch Services so the zterminal:// scheme resolves.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" || true

echo "✓ Built $APP"
echo "  open \"$APP\"   # to launch"
