#!/usr/bin/env bash
# Builds the release bundle and verifies the download size stays under 60 MB.
# Needs: flutter, and bundletool on PATH (https://github.com/google/bundletool) for per-device sizes.
set -euo pipefail
cd "$(dirname "$0")/.."
LIMIT=$((60 * 1024 * 1024))

flutter build appbundle --release --obfuscate --split-debug-info=build/symbols \
  ${ADMOB_BANNER_ID:+--dart-define=ADMOB_BANNER_ID=$ADMOB_BANNER_ID} \
  ${PRIVACY_URL:+--dart-define=PRIVACY_URL=$PRIVACY_URL}

AAB=build/app/outputs/bundle/release/app-release.aab
echo "AAB size: $(du -h "$AAB" | cut -f1)"

if command -v bundletool >/dev/null 2>&1; then
  bundletool build-apks --bundle="$AAB" --output=build/omni.apks --overwrite >/dev/null
  MAX=$(bundletool get-size total --apks=build/omni.apks | tail -n 1 | cut -d, -f2)
  echo "Largest download for any device configuration: $((MAX / 1024 / 1024)) MB"
  [ "$MAX" -lt "$LIMIT" ] && echo "OK: under 60 MB" || { echo "FAIL: over 60 MB"; exit 1; }
else
  SIZE=$(stat -c%s "$AAB" 2>/dev/null || stat -f%z "$AAB")
  echo "bundletool not found: using the AAB size as an upper bound (real downloads are smaller)."
  [ "$SIZE" -lt "$LIMIT" ] && echo "OK: AAB under 60 MB" || { echo "WARNING: AAB over 60 MB, install bundletool to measure real downloads"; exit 1; }
fi
