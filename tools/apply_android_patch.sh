#!/usr/bin/env bash
# Run once after `flutter create` and `flutterfire configure` (safe to re-run).
# Optional: ADMOB_APP_ID=ca-app-pub-xxx~yyy ./tools/apply_android_patch.sh
set -euo pipefail
cd "$(dirname "$0")/.."

[ -d android ] || { echo "android/ not found. Run: flutter create --org com.omni --project-name omni --platforms=android ."; exit 1; }

# 1. Native code
DIR=android/app/src/main/kotlin/com/omni/omni
mkdir -p "$DIR"
cp android_patch/*.kt "$DIR/"

# 2. Gradle dependencies + minSdk 23 (Firebase)
DEPS=(
  "com.google.android.play:integrity:1.3.0"
  "androidx.media3:media3-transformer:1.4.1"
  "androidx.media3:media3-effect:1.4.1"
  "androidx.media3:media3-common:1.4.1"
  "com.tom-roush:pdfbox-android:2.0.27.0"
)
if [ -f android/app/build.gradle.kts ]; then
  G=android/app/build.gradle.kts
  for d in "${DEPS[@]}"; do grep -q "$d" "$G" || printf '\ndependencies {\n    implementation("%s")\n}\n' "$d" >> "$G"; done
  sed -i.bak 's/minSdk = flutter.minSdkVersion/minSdk = 23/' "$G" && rm -f "$G.bak"
else
  G=android/app/build.gradle
  for d in "${DEPS[@]}"; do grep -q "$d" "$G" || printf "\ndependencies {\n    implementation '%s'\n}\n" "$d" >> "$G"; done
  sed -i.bak 's/minSdkVersion flutter.minSdkVersion/minSdkVersion 23/' "$G" && rm -f "$G.bak"
fi

# 3. local_auth needs an AppCompat launch theme
for f in android/app/src/main/res/values/styles.xml android/app/src/main/res/values-night/styles.xml; do
  [ -f "$f" ] && sed -i.bak 's#@android:style/Theme.Light.NoTitleBar#Theme.AppCompat.Light.NoTitleBar#; s#@android:style/Theme.Black.NoTitleBar#Theme.AppCompat.NoTitleBar#' "$f" && rm -f "$f.bak"
done

# 4. Manifest: permissions + AdMob app id (defaults to Google's TEST app id)
APP_ID="${ADMOB_APP_ID:-ca-app-pub-3940256099942544~3347511713}" python3 - <<'PY'
import os, re
p = "android/app/src/main/AndroidManifest.xml"
s = open(p, encoding="utf-8").read()
perms = [
    '<uses-permission android:name="android.permission.INTERNET"/>',
    '<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>',
    '<uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>',
    '<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>',
    '<uses-permission android:name="android.permission.USE_BIOMETRIC"/>',
]
for perm in perms:
    name = re.search(r'name="([^"]+)"', perm).group(1)
    if name not in s:
        s = s.replace("<application", perm + "\n    <application", 1)
if "com.google.android.gms.ads.APPLICATION_ID" not in s:
    meta = '\n        <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="%s"/>' % os.environ["APP_ID"]
    s = re.sub(r"(<application[^>]*>)", lambda m: m.group(1) + meta, s, count=1)
open(p, "w", encoding="utf-8").write(s)
PY

# Always apply release configuration (without signing config for debug builds)
ADD_SIGNING_CONFIG="${ADD_SIGNING_CONFIG:-false}" python3 tools/configure_release.py
echo "Android patch applied."
