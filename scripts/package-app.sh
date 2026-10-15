#!/usr/bin/env bash
# Build a double-clickable PulseBar.app for local install / GitHub Releases.
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

echo "→ Building release binary…"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/$APP_NAME"

echo "→ Assembling $APP_NAME.app…"
rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"

cp "$BIN" "$MACOS/$APP_NAME"
chmod +x "$MACOS/$APP_NAME"
cp "$ROOT/PulseBar/Info.plist" "$CONTENTS/Info.plist"

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

if command -v codesign >/dev/null; then
  codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true
fi

echo "✓ Built $APP_DIR"
echo "  Open it once, then grant Accessibility if you use Clean Keyboard."
echo "  Optional: drag into /Applications"
