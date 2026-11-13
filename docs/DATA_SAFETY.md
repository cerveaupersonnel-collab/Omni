# Google Play: Data safety form and declarations for OMNI

Answer the Play Console forms with the values below. They describe what this code actually does.
Re-check them whenever you add an SDK (analytics, crash reporting, another ad network).

## 1. Data safety > Data collection and security
- Does your app collect or share any of the required user data types? **Yes**
- Is all of the user data collected by your app encrypted in transit? **Yes**
- Do you provide a way for users to request that their data is deleted? **Yes**
  - In-app: Account & privacy > Delete account and data.
  - Web link (required): the hosted `delete-account.html` (see README, "Legal pages").

## 2. Data types
| Category > type | Collected | Shared | Optional | Purposes |
|---|---|---|---|---|
| Personal info > Email address | Yes (Google sign-in) | No | Yes | Account management; App functionality |
| Personal info > Name | Yes (Google profile stored by Firebase Auth) | No | Yes | Account management |
| Personal info > User IDs (Firebase UID) | Yes | No | No | App functionality; Account management; Fraud prevention, security |
| Financial info > Purchase history | Yes (subscription product, expiry, purchase token) | No | Yes | App functionality |
| App activity > App interactions | Yes (daily per-feature counters) | No* | No | App functionality |
| Files and docs > Files and docs | Yes (text of a PDF you choose for Chat with PDF) | No (processor: OpenAI) | Yes | App functionality |
| Messages > Other in-app messages | Yes (your questions in Chat with PDF) | No (processor: OpenAI) | Yes | App functionality |
| Device or other IDs > Device or other IDs | Yes (Firebase installation ID; Advertising ID for free users) | Yes (Advertising ID with Google AdMob) | No | App functionality; Advertising or marketing; Fraud prevention, security |
| Location > Approximate location | Yes (derived from IP by AdMob, free users) | Yes (Google AdMob) | No | Advertising or marketing |
| App info and performance > Diagnostics | Yes (AdMob SDK, free users) | Yes (Google AdMob) | No | Advertising or marketing; Analytics |

\* AdMob also collects ad interactions (App activity > App interactions) and shares them with Google.

**Not collected (processed only on the device):** photos and videos (Clean, Compressor, Vault, Scan), audio, files and documents other than the PDF text above, contacts, SMS, call logs, health, precise location.

Ephemeral processing: Chat with PDF text is sent to our Cloud Function and forwarded to OpenAI in the same request. OMNI does not store it. Because OpenAI processes it under its own API terms, it is declared above to stay on the safe side.

> Verify the AdMob rows against Google's current "Declare data use for the Google Mobile Ads SDK" page before submitting: the list changes with SDK versions.

## 3. App content
- Ads: **Yes, contains ads** (banner ads for free users; none for Pro).
- Target audience: **18 and over** (keeps the app out of the Families policy).
- Privacy policy URL: the hosted `privacy.html` (see README).
- App access: all features work without logging in. Google sign-in is only needed to buy or restore Pro.
  Give reviewers a Play license-tester account if they need to test the purchase flow.
- Financial features / health / government / news: none.
- Content rating (IARC): complete the questionnaire honestly. The app has in-app purchases and ads and no user-generated content shared between users.

## 4. Permissions declarations
| Permission | Why | Console form |
|---|---|---|
| READ_MEDIA_IMAGES, READ_MEDIA_VIDEO (Android 13+) and READ_EXTERNAL_STORAGE (maxSdk 32) | Omni Clean must analyze the whole library to find duplicates, blurry photos and large videos; the Vault lists the gallery so you can choose what to hide. Files are analyzed on the device and nothing is uploaded. | Photo and video permissions declaration |
| USE_BIOMETRIC | Unlock the Vault with fingerprint/face | None |
| INTERNET | Firebase, AI and ads | None |
| com.google.android.gms.permission.AD_ID | AdMob (declare the advertising ID use: Advertising) | Advertising ID declaration |
| com.android.vending.BILLING | Subscriptions | None |

Suggested text for the photo/video declaration: "Omni Clean is a storage cleaner. Its core function is to scan the user's entire photo and video library on the device to find duplicates, blurry photos, large videos and WhatsApp media, and to delete them after the user approves a system dialog. A one-time picker cannot provide this. The Vault lets the user pick items from their gallery to move into private storage. No media leaves the device."

MANAGE_EXTERNAL_STORAGE is intentionally **not** requested: Google Play does not allow it for cleaner apps.

## 5. Subscriptions
Products `omni_pro_monthly` and `omni_pro_yearly` need an active base plan, a price, and a localized title and description. Add the "cancel anytime in Google Play" wording (already on the paywall).
