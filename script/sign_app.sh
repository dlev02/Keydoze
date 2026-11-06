#!/bin/bash
# Signs a Keydoze.app from the inside out with the given codesign options, Sparkle's helpers first.
# No --deep: it would apply one set of options to everything.
#   script/sign_app.sh path/to/Keydoze.app --force --sign IDENTITY [--options runtime] [--timestamp]
set -euo pipefail
app="$1"; shift
sparkle="$app/Contents/Frameworks/Sparkle.framework"
codesign "$@" "$sparkle/Versions/B/Autoupdate"
codesign "$@" "$sparkle/Versions/B/Updater.app"
codesign "$@" "$sparkle"
codesign "$@" "$app"
