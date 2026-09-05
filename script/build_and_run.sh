#!/bin/bash
set -euo pipefail
KEYDOZE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$KEYDOZE_ROOT"
KEYDOZE_MODE="${1:---run}"
case "$KEYDOZE_MODE" in
  --run|--build|--release|--simulate|--probe|--verify|--logs|--telemetry|--debug) ;;
  *) echo "Unknown mode: $KEYDOZE_MODE" >&2; exit 2 ;;
esac
KEYDOZE_CONFIG=debug
if [[ "$KEYDOZE_MODE" == --release ]]; then KEYDOZE_CONFIG=release; fi
# Kill only the executable in this project's stable bundle location.
KEYDOZE_APP="$KEYDOZE_ROOT/dist/Keydoze.app"
KEYDOZE_PIDS="$(pgrep -x Keydoze)" || KEYDOZE_PGREP_STATUS=$?
if [[ "${KEYDOZE_PGREP_STATUS:-0}" -gt 1 ]]; then
  echo "Cannot inspect running apps. Build aborted before replacing the bundle." >&2
  exit 1
fi
for KEYDOZE_PID in $KEYDOZE_PIDS; do
  if ps -p "$KEYDOZE_PID" -o command= | /usr/bin/grep -Fq "$KEYDOZE_APP/Contents/MacOS/Keydoze"; then
    kill "$KEYDOZE_PID" || true
    for KEYDOZE_ATTEMPT in {1..50}; do
      if ! kill -0 "$KEYDOZE_PID" 2>/dev/null; then break; fi
      sleep 0.1
    done
    if kill -0 "$KEYDOZE_PID" 2>/dev/null; then
      echo "Keydoze did not exit. Stop it before replacing a permission-bearing app." >&2
      exit 1
    fi
  fi
done
swift build --disable-sandbox -c "$KEYDOZE_CONFIG"
KEYDOZE_BIN="$(swift build --disable-sandbox -c "$KEYDOZE_CONFIG" --show-bin-path)"
mkdir -p "$KEYDOZE_APP/Contents/MacOS" "$KEYDOZE_APP/Contents/Resources"
cp "$KEYDOZE_BIN/Keydoze" "$KEYDOZE_APP/Contents/MacOS/Keydoze"
cp Resources/Info.plist "$KEYDOZE_APP/Contents/Info.plist"
cp LICENSE NOTICE PRIVACY.md Resources/Credits.html "$KEYDOZE_APP/Contents/Resources/"
cp Resources/Keydoze.icns "$KEYDOZE_APP/Contents/Resources/Keydoze.icns"
KEYDOZE_SIGN_IDENTITY="${KEYDOZE_SIGN_IDENTITY:-}"
if [[ -z "$KEYDOZE_SIGN_IDENTITY" ]]; then
  KEYDOZE_SIGN_IDENTITY="$(security find-identity -v -p codesigning | awk '/Apple Development:/{print $2; exit}')"
fi
KEYDOZE_SIGN_OPTIONS=(--force --sign "${KEYDOZE_SIGN_IDENTITY:--}")
if [[ "$KEYDOZE_CONFIG" == release ]]; then KEYDOZE_SIGN_OPTIONS+=(--options runtime --timestamp=none); fi
codesign "${KEYDOZE_SIGN_OPTIONS[@]}" "$KEYDOZE_APP"
codesign --verify --strict "$KEYDOZE_APP"
case "$KEYDOZE_MODE" in
  --build|--release) echo "$KEYDOZE_APP" ;;
  --simulate) open -n "$KEYDOZE_APP" --args --simulate ;;
  --probe) open -n "$KEYDOZE_APP" --args --probe-permission "$KEYDOZE_ROOT/dist/permission-probe.json" ;;
  --verify) open -n "$KEYDOZE_APP"; sleep 1; pgrep -x Keydoze ;;
  --logs|--telemetry) open -n "$KEYDOZE_APP"; /usr/bin/log stream --info --predicate 'process == "Keydoze"' ;;
  --debug) lldb -- "$KEYDOZE_APP/Contents/MacOS/Keydoze" ;;
  --run) open -n "$KEYDOZE_APP" ;;
  *) echo "Unknown mode: $KEYDOZE_MODE" >&2; exit 2 ;;
esac
