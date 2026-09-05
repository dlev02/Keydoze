#!/bin/bash
set -euo pipefail
KEYDOZE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$KEYDOZE_ROOT"
KEYDOZE_ICONSET="$(mktemp -d "${TMPDIR:-/tmp/}keydoze-icon.XXXXXX")/Keydoze.iconset"
mkdir -p "$KEYDOZE_ICONSET"
trap 'rm -rf "${KEYDOZE_ICONSET%/*}"' EXIT
for KEYDOZE_SIZE in 16 32 128 256 512; do
  sips -z "$KEYDOZE_SIZE" "$KEYDOZE_SIZE" Resources/Brand/Keydoze-source.png --out "$KEYDOZE_ICONSET/icon_${KEYDOZE_SIZE}x${KEYDOZE_SIZE}.png" >/dev/null
  KEYDOZE_DOUBLE=$((KEYDOZE_SIZE * 2))
  sips -z "$KEYDOZE_DOUBLE" "$KEYDOZE_DOUBLE" Resources/Brand/Keydoze-source.png --out "$KEYDOZE_ICONSET/icon_${KEYDOZE_SIZE}x${KEYDOZE_SIZE}@2x.png" >/dev/null
done
iconutil -c icns "$KEYDOZE_ICONSET" -o Resources/Keydoze.icns
sips -z 512 512 Resources/Brand/Keydoze-source.png --out Resources/Brand/Keydoze.png >/dev/null
echo "Built Resources/Keydoze.icns"
