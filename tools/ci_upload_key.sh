#!/usr/bin/env bash
# Writes the upload keystore and android/key.properties from Codemagic secrets (release builds).
set -euo pipefail
cd "$(dirname "$0")/.."
if [ -n "${CM_KEYSTORE:-}" ]; then
  JKS="${CM_BUILD_DIR:-$PWD}/upload.jks"
  echo "$CM_KEYSTORE" | base64 --decode > "$JKS"
  printf 'storePassword=%s\nkeyPassword=%s\nkeyAlias=%s\nstoreFile=%s\n' \
    "$CM_KEYSTORE_PASSWORD" "$CM_KEY_PASSWORD" "$CM_KEY_ALIAS" "$JKS" > android/key.properties
  echo "Upload key configured."
else
  echo "WARNING: CM_KEYSTORE is empty. The bundle will be debug-signed and Google Play will reject it."
fi
