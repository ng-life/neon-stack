#!/usr/bin/env bash
# Generate every standard macOS icon representation from the source artwork.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICON_DIR="$ROOT_DIR/.build/AppIcon.iconset"
mkdir -p "$ICON_DIR"
for SIZE in 16 32 128 256 512; do
  sips -z "$SIZE" "$SIZE" "$ROOT_DIR/Assets/AppIcon.png" --out "$ICON_DIR/icon_${SIZE}x${SIZE}.png" >/dev/null
  DOUBLE_SIZE=$((SIZE * 2))
  sips -z "$DOUBLE_SIZE" "$DOUBLE_SIZE" "$ROOT_DIR/Assets/AppIcon.png" --out "$ICON_DIR/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil -c icns "$ICON_DIR" -o "$ROOT_DIR/Assets/AppIcon.icns"
