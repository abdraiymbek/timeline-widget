#!/bin/bash
# Timeline -- build and install.
# Generates the Xcode project (if xcodegen is installed), builds Release with
# ad-hoc signing, copies Timeline.app to /Applications, registers the widget
# extension, and opens the app.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if command -v xcodegen >/dev/null 2>&1; then
    echo "==> Generating project with xcodegen"
    xcodegen generate
else
    echo "==> xcodegen not found; using committed TimelineWidget.xcodeproj"
fi

echo "==> Building Release"
xcodebuild \
    -project TimelineWidget.xcodeproj \
    -scheme Timeline \
    -configuration Release \
    -derivedDataPath build \
    CODE_SIGN_IDENTITY=- \
    DEVELOPMENT_TEAM= \
    build

APP="$ROOT/build/Build/Products/Release/Timeline.app"
DEST="/Applications/Timeline.app"

if [ ! -d "$APP" ]; then
    echo "error: build product not found at $APP" >&2
    exit 1
fi

echo "==> Installing to $DEST"
rm -rf "$DEST"
cp -R "$APP" "$DEST"

APPEX="$DEST/Contents/PlugIns/TimelineWidgetExtension.appex"
if [ -d "$APPEX" ]; then
    echo "==> Registering widget extension"
    pluginkit -a "$APPEX" || true
else
    echo "note: no appex at $APPEX (widget registers on first launch)"
fi

echo "==> Opening Timeline"
open "$DEST"
echo "Done. Right-click the desktop, choose Edit Widgets, search for Timeline."
