# OMNI: One App. For Everything.

Flutter + Firebase super app: Scan (OCR), Chat with PDF, Clean, Video Compressor, Secure Vault.
Freemium (3 free uses per feature per day with banner ads) and OMNI Pro subscriptions
(`omni_pro_monthly`, `omni_pro_yearly`). Pro status is granted only by the server.

```
lib/                Flutter app (Clean Architecture: data / domain / presentation, Riverpod)
android_patch/      Native Kotlin (Play Integrity, Media3 compressor, MediaStore, PdfBox), R8 + network config
functions/          Firebase Functions (TypeScript): AI proxy, integrity, billing, usage, account deletion
hosting/            Privacy policy + account deletion pages (rendered with your details)
tools/              apply_android_patch.sh, configure_release.py, check_size.sh, render_legal.sh
docs/               DATA_SAFETY.md, STORE_LISTING.md
CHECKLIST.md        What is ready to publish and what still needs you
```

## Prerequisites
A current stable Flutter SDK (Google Play now requires targeting API 36, which needs a recent Flutter/AGP; the `>=3.22` in
pubspec is only the floor), Android Studio, Node 20, Firebase CLI (`npm i -g firebase-tools`), FlutterFire CLI
(`dart pub global activate flutterfire_cli`), a Google Play developer account, an AdMob account, an OpenAI API key.

## 1. Firebase
1. Create a project, upgrade to **Blaze**.
2. Authentication: enable **Anonymous** and **Google**. Firestore: create the database (production mode).
3. App Check: register the Android app with the **Play Integrity** provider, then enforce for Cloud Functions.
4. Project settings > Your apps > Android (`com.omni.omni`): add the **SHA-1 and SHA-256** of (a) your debug key, (b) your upload key,
   (c) the **Play App Signing key** (Play Console > App integrity). Google Sign-In and Play Integrity fail without them.
5. Enable APIs: Play Integrity API, Google Play Android Developer API, Pub/Sub, Secret Manager, Cloud Firestore.

## 2. Flutter project
```bash
flutter create --org com.omni --project-name omni --platforms=android .   # keeps lib/ and pubspec.yaml
flutterfire configure                                                      # lib/firebase_options.dart + google-services.json
flutter pub get
./tools/apply_android_patch.sh                                             # native code, permissions, R8, SDK 36, signing, network config
```
`ADMOB_APP_ID=ca-app-pub-xxxx~yyyy ./tools/apply_android_patch.sh` writes your real AdMob app id
(the default is Google's test id, which must not ship).
Check the billing library after `flutter pub get`:
`cd android && ./gradlew app:dependencies --configuration releaseRuntimeClasspath | grep -i billingclient`
It must show **8.0.0 or newer** (Play requirement). If it does not, upgrade `in_app_purchase_android`.

## 3. Backend (functions/)
```bash
cd functions && npm install && cd ..
firebase use <project-id>
firebase functions:secrets:set OPENAI_API_KEY          # the key lives only in Secret Manager
cp functions/.env.example functions/.env              # set PLAY_CERT_SHA256_DIGESTS (Play App Signing SHA-256), keep ENFORCE_INTEGRITY=true
firebase deploy --only functions,firestore:rules,storage
```
Then follow `functions/README.md` for Pub/Sub (`play-rtdn`), the Play Console API access link, and Firestore TTL policies.

## 4. Play Console
1. Create the app (package `com.omni.omni`). Enroll in **Play App Signing**.
2. Create an **upload key** and `android/key.properties` (never commit them):
   ```bash
   keytool -genkey -v -keystore ~/omni-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   ```
   storePassword=...   keyPassword=...   keyAlias=upload   storeFile=/home/you/omni-upload.jks
   ```
3. Monetize > Subscriptions: create `omni_pro_monthly` ($6.99) and `omni_pro_yearly` ($29.99), each with an active base plan.
4. Monetize > Monetization setup > Real-time developer notifications: topic `projects/<project-id>/topics/play-rtdn`.
5. Setup > API access: link the Cloud project and grant the Functions service account "View financial data" and "Manage orders and subscriptions".
6. Test: add yourself under Settings > License testing, upload to **Internal testing**, install from the Play link
   (Play Integrity and billing only work for Play-installed builds).

## 5. AdMob
Create the app and a **banner** ad unit. In Privacy & messaging, create and publish a **GDPR message** (consent, UMP).
Pass the unit at build time: `--dart-define=ADMOB_BANNER_ID=ca-app-pub-xxxx/yyyy`. Without it, release builds show no ads.

## 6. Legal pages (required by Play)
```bash
COMPANY_NAME="Your Company" CONTACT_EMAIL="privacy@yourdomain.com" ./tools/render_legal.sh
firebase deploy --only hosting
```
Use `https://<project-id>.web.app/privacy.html` as the privacy policy URL and `.../delete-account.html` as the account deletion URL.

## 7. Build, size check, release
```bash
export ADMOB_BANNER_ID=ca-app-pub-xxxx/yyyy PRIVACY_URL=https://<project-id>.web.app/privacy.html
./tools/check_size.sh        # builds the obfuscated AAB and fails if the download is over 60 MB (needs bundletool for exact numbers)
```
The AAB is `build/app/outputs/bundle/release/app-release.aab`. Keep `build/symbols` (Dart obfuscation map) safe.
R8 produces `mapping.txt`; Play Console receives it with the bundle.
Complete **Data safety** and the declarations from `docs/DATA_SAFETY.md`, then upload to Internal, Closed (12 testers for 14 days are required
for new personal developer accounts), and finally Production.

## Development
- Debug run: `flutter run --dart-define=OMNI_SKIP_INTEGRITY=true` and set `ENFORCE_INTEGRITY=false` in `functions/.env.local`
  with the emulator (`cd functions && npm run serve`). Register the App Check debug token printed in logcat.
- Tests: `flutter test`. Static checks: `flutter analyze` and `cd functions && npm run lint`.

## Architecture notes
- **Security**: Play Integrity verified on the server (nonce, package, certificate digest, licensing); App Check on every callable;
  Pro entitlement written only by Cloud Functions after Google Play verification; Firestore rules deny client writes;
  OpenAI key only in Secret Manager; R8 minify + Dart obfuscation; HTTPS only with system trust anchors.
  Certificate pinning of Google endpoints is deliberately not used: Google rotates its certificates and pinning would break the app.
- **Free limit**: reserved when an operation starts, kept when it succeeds, refunded when it is cancelled or fails (max 3 refunds per feature per day).
- **Subscriptions** are bound to a Google account (obfuscated account id) so Restore Purchase works after a reinstall.
- **Offline-first**: Scan, Clean, Compress and Vault work offline with a local free counter; AI and purchases need a connection.
- **Why not MANAGE_EXTERNAL_STORAGE / ffmpeg_kit**: see CHECKLIST.md.

## Codemagic
`codemagic.yaml` has two workflows: **omni-android-debug** (debug APK for quick phone tests, integrity check skipped)
and **omni-android** (obfuscated release AAB). Secrets are listed at the top of the file. If a Firebase secret is missing the build
uses a stub so it still compiles; such a build cannot reach Firebase and must not be uploaded to Google Play.
A debug or sideloaded APK shows "This app is not secure" in release mode: Play Integrity only trusts Play-installed builds.
