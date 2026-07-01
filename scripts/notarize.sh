#!/usr/bin/env bash
# Build, Developer-ID sign, notarize, and staple zTerminal for direct distribution.
#
# Prerequisites (Apple Developer account, $99/yr):
#   • A "Developer ID Application" certificate in your login keychain.
#   • A notarytool keychain profile (one-time):
#       xcrun notarytool store-credentials zTerminal-notary \
#         --apple-id "you@example.com" --team-id "TEAMID" --password "app-specific-pw"
#
# Usage:
#   DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" \
#   TEAM_ID="TEAMID" \
#   NOTARY_PROFILE="zTerminal-notary" \
#   ./scripts/notarize.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${DEVELOPER_ID:?Set DEVELOPER_ID to your 'Developer ID Application: … (TEAMID)' identity}"
: "${TEAM_ID:?Set TEAM_ID to your 10-char Apple team id}"
: "${NOTARY_PROFILE:=zTerminal-notary}"

DD="$ROOT/build/notarize-dd"
APP="$DD/Build/Products/Release/zTerminal.app"
OUT="$ROOT/build/dist"
ZIP="$OUT/zTerminal.zip"

echo "▸ Regenerating project"
( cd "$ROOT" && xcodegen generate >/dev/null )

echo "▸ Building Release, Developer-ID signed + hardened runtime"
xcodebuild -project "$ROOT/zTerminal.xcodeproj" -scheme zTerminal \
  -configuration Release -derivedDataPath "$DD" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$DEVELOPER_ID" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  ENABLE_HARDENED_RUNTIME=YES \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime" \
  build

echo "▸ Verifying signature (app + embedded extension)"
codesign --verify --deep --strict --verbose=2 "$APP"

mkdir -p "$OUT"
echo "▸ Zipping for notarization"
/usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"

echo "▸ Submitting to notarytool (waits for result)"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

echo "▸ Stapling the ticket"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "▸ Re-zipping the stapled app"
rm -f "$ZIP"
/usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"

echo "✓ Notarized + stapled: $APP"
echo "  Distributable: $ZIP"
echo "  (Optionally wrap in a .dmg with create-dmg for a nicer installer.)"
