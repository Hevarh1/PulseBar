#!/usr/bin/env bash
# Build a double-clickable PulseBar.app for local install / GitHub Releases.
#
# Optional (recommended for public downloads):
#   export CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
#   export NOTARY_PROFILE="PulseBar"   # from: xcrun notarytool store-credentials
#   ./scripts/package-app.sh
#
# Without those, the script ad-hoc signs (fine locally; Gatekeeper will warn on download).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="PulseBar"
DIST_DIR="$ROOT/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
ICON_PNG="$ROOT/PulseBar/Resources/AppIcon.png"
ZIP_PATH="$DIST_DIR/$APP_NAME.app.zip"

ENTITLEMENTS="$ROOT/scripts/PulseBar.entitlements"

detect_developer_id() {
  security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Developer ID Application: .*\)".*/\1/p' \
    | head -1
}

echo "→ Building release binary…"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/$APP_NAME"

echo "→ Assembling $APP_NAME.app…"
rm -rf "$APP_DIR" "$ZIP_PATH"
mkdir -p "$MACOS" "$RESOURCES"

cp "$BIN" "$MACOS/$APP_NAME"
chmod +x "$MACOS/$APP_NAME"
cp "$ROOT/PulseBar/Info.plist" "$CONTENTS/Info.plist"

# SPM resource bundle (Bundle.module) — required or the dashboard crashes on open.
RESOURCE_BUNDLE="$(dirname "$BIN")/${APP_NAME}_${APP_NAME}.bundle"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
  cp -R "$RESOURCE_BUNDLE" "$RESOURCES/"
else
  echo "warning: missing $RESOURCE_BUNDLE (Bundle.module assets may be unavailable)" >&2
fi

/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$CONTENTS/Info.plist" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string PulseBar" "$CONTENTS/Info.plist" 2>/dev/null \
  || true

if [[ -f "$ICON_PNG" ]]; then
  echo "→ Creating AppIcon.icns…"
  TMP="$(mktemp -d)"
  ICONSET="$TMP/AppIcon.iconset"
  mkdir -p "$ICONSET"
  for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$ICON_PNG" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$ICON_PNG" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"
  cp "$ICON_PNG" "$RESOURCES/AppIcon.png"
  rm -rf "$TMP"
fi

IDENTITY="${CODESIGN_IDENTITY:-$(detect_developer_id)}"
if [[ -z "${IDENTITY}" ]]; then
  IDENTITY="-"
fi

echo "→ Codesigning with: $IDENTITY"
SIGN_ARGS=(--force --deep --sign "$IDENTITY")
if [[ "$IDENTITY" != "-" ]]; then
  # Hardened Runtime + secure timestamp required for notarization / Developer ID.
  SIGN_ARGS+=(--options runtime --timestamp)
fi
if [[ -f "$ENTITLEMENTS" && "$IDENTITY" != "-" ]]; then
  SIGN_ARGS+=(--entitlements "$ENTITLEMENTS")
fi
# Nested resource bundles first, then the app.
if [[ -d "$RESOURCES/${APP_NAME}_${APP_NAME}.bundle" ]]; then
  if [[ "$IDENTITY" != "-" ]]; then
    codesign --force --options runtime --timestamp --sign "$IDENTITY" \
      "$RESOURCES/${APP_NAME}_${APP_NAME}.bundle" 2>/dev/null || true
  else
    codesign --force --sign "$IDENTITY" \
      "$RESOURCES/${APP_NAME}_${APP_NAME}.bundle" 2>/dev/null || true
  fi
fi
codesign "${SIGN_ARGS[@]}" "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

if [[ "$IDENTITY" == "-" ]]; then
  echo "⚠ Ad-hoc signed only — Gatekeeper will warn on download."
  echo "  Create a Developer ID Application certificate, then re-run with:"
  echo "    export CODESIGN_IDENTITY=\"Developer ID Application: …\""
  echo "    export NOTARY_PROFILE=\"PulseBar\""
else
  echo "→ Zipping for notarization…"
  ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

  if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    echo "→ Submitting to Apple notary service (profile: $NOTARY_PROFILE)…"
    xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
    echo "→ Stapling notarization ticket…"
    xcrun stapler staple "$APP_DIR"
    # Rebuild zip with stapled app for GitHub Releases.
    rm -f "$ZIP_PATH"
    ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"
    echo "✓ Notarized + stapled"
  else
    echo "⚠ Signed with Developer ID but NOTARY_PROFILE unset — not notarized yet."
    echo "  Store credentials once, then re-run:"
    echo "    xcrun notarytool store-credentials PulseBar --apple-id YOU@email --team-id TEAMID"
    echo "    export NOTARY_PROFILE=PulseBar"
    echo "    ./scripts/package-app.sh"
  fi
fi

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "→ Creating $APP_NAME.app.zip…"
  ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"
fi

echo "✓ Built $APP_DIR"
echo "  Zip: $ZIP_PATH"
echo "  Open it once, then grant Accessibility if you use Clean Keyboard."
echo "  Optional: drag into /Applications"
