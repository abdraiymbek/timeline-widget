#!/bin/bash
# Renders widget snapshots with demo data to /tmp/timeline-renders/ .
# The sandboxed app can't write to /tmp, so it renders into its own container
# and we copy the PNGs out.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/build/Build/Products/Release/Timeline.app}"
OUT="/tmp/timeline-renders"
CONTAINER_TMP="$HOME/Library/Containers/com.abdraiymbek.timelinewidget/Data/tmp/timeline-renders"

rm -rf "$CONTAINER_TMP" "$OUT"
mkdir -p "$CONTAINER_TMP" "$OUT"

"$APP/Contents/MacOS/Timeline" --render-snapshots "$CONTAINER_TMP"

cp -f "$CONTAINER_TMP"/*.png "$OUT"/
echo "Snapshots in $OUT:"
ls -la "$OUT"
