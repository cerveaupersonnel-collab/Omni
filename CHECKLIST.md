# Final status

## Built and in this project
- 5 modules: Scan (ML Kit scanner + OCR + PDF/JPG), Chat with PDF, Clean (MediaStore + system delete dialog), Video Compressor (Media3), Secure Vault (biometric, private storage, FLAG_SECURE).
- Backend: OpenAI proxy (`gpt-4o-mini`, key in Secret Manager), server-side Play Integrity, Play Billing verification + RTDN webhook, usage limits with reserve/refund, account deletion.
- Client: App Check (Play Integrity), blocking screen ("This app is not secure" then closes), paywall with Restore Purchase, banner ads for free users only (UMP consent), Google Sign-In to keep subscriptions after reinstall, account and privacy screen.
- Release: R8 minify + resource shrinking, Dart obfuscation, upload-key signing, target/compile SDK 36, network security config (HTTPS only), backup disabled.
- Store: Data safety answers, permission declarations, privacy policy + deletion pages, listing draft, unit tests.

## You must do (cannot be done from here)
1. Run the setup in README (Firebase, Play Console, AdMob) and put your real values in: `google-services.json`, `PLAY_CERT_SHA256_DIGESTS`, `OPENAI_API_KEY`, `ADMOB_APP_ID`, `ADMOB_BANNER_ID`, `PRIVACY_URL`.
2. Register SHA-1/SHA-256 keys in Firebase (debug, upload, Play App Signing).
3. Create the upload keystore and `android/key.properties`.
4. Render and deploy the legal pages with your company name and contact email.
5. Fill in the Play Console: Data safety, photo/video permission declaration, content rating, store listing, screenshots.
6. Run `flutter test`, `flutter analyze`, `./tools/check_size.sh`, then test on real devices from an Internal testing track.

## Honest limitations
- **Nothing was compiled or run.** The code was written without a Flutter/Android toolchain. Expect a first round of compile fixes (plugin versions, small API differences). Treat it as a complete first draft, not a verified build.
- **Play approval and revenue cannot be guaranteed.** The photo/video permission declaration is reviewed by humans, and a cleaner app is a category Google scrutinizes. The $1M/month goal depends on marketing, not code.
- **App size is unmeasured.** Rough expectation per device: 35-50 MB (Flutter engine, ML Kit text model, PdfBox, Media3, Firebase, ads). `tools/check_size.sh` gives the real number. If it exceeds 60 MB, drop PdfBox or use an unbundled ML Kit text model.
- **Billing Library 8** is required by Google Play; the version used depends on `in_app_purchase_android`. Verify with the Gradle command in README.
- **16 KB page size** (required for uploads with native code from 1 Feb 2027): use a current Flutter/AGP/NDK and confirm with Play Console's pre-launch checks.
- **Free limits on on-device features** are enforced by Play Integrity, not by the device. A rooted or modified client is blocked, but no client-side limit is unbreakable.
- **Clean** needs Android 11+ and does not scan APKs or WhatsApp documents (they need MANAGE_EXTERNAL_STORAGE, which Play rejects for cleaners). Blur detection is an estimate.
- **Compressor** is near-lossless at the chosen bitrate, not lossless.
- **No Crashlytics or Analytics** were added on purpose (less data to declare). Use Play Console's Android vitals, or add them and update the Data safety form.
- **Pro offline**: Pro is recognized only online; offline the free counter applies.
- Subscriptions made before Google Sign-In existed were bound to an anonymous account and cannot be restored after a reinstall.
