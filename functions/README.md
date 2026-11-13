# OMNI Functions (Node 20 + TypeScript)

## Functions
| Name | Type | Purpose |
|---|---|---|
| `chatWithPDF` | callable | OpenAI `gpt-4o-mini` proxy. Key stays in Secret Manager. |
| `getIntegrityNonce` / `verifyIntegrity` | callable | Server-side Play Integrity check. |
| `beginFeatureUse` / `finishFeatureUse` / `getUsageStatus` | callable | 3 free uses/day/feature. A use is reserved at start, kept on success, refunded on cancel/failure (max 3 refunds/day/feature). |
| `deleteAccount` | callable | Erases the user's server data and auth account. |
| `getBillingAccountId` / `verifyPurchase` | callable | Validates subscriptions with the Play Developer API and writes `users/{uid}.isPro`. |
| `playBillingWebhook` | Pub/Sub | Handles Play Real-time Developer Notifications. |

All callables enforce Firebase App Check (Play Integrity provider).

## Setup
1. `cd functions && npm install`
2. `firebase login && firebase use <project-id>` (Blaze plan required).
3. OpenAI key (never in the app): `firebase functions:secrets:set OPENAI_API_KEY`
4. `cp .env.example .env` and set `PLAY_CERT_SHA256_DIGESTS` to the SHA-256 fingerprint of your **Play App Signing key**.
5. Enable APIs: Play Integrity API, Google Play Android Developer API, Cloud Pub/Sub, Secret Manager.
6. Firebase Console > App Check: register the Android app with the **Play Integrity** provider and enable enforcement.
7. Play Console > Setup > API access: link the Cloud project, invite the Functions service account
   (`<project-number>-compute@developer.gserviceaccount.com`) with "View financial data" and "Manage orders and subscriptions".
8. Create the topic and grant publish rights to Google:
   `gcloud pubsub topics create play-rtdn`
   `gcloud pubsub topics add-iam-policy-binding play-rtdn --member=serviceAccount:google-play-developer-notifications@system.gserviceaccount.com --role=roles/pubsub.publisher`
   Then Play Console > Monetize > Monetization setup > Real-time developer notifications > topic `projects/<project-id>/topics/play-rtdn`.
9. TTL cleanup:
   `gcloud firestore fields ttls update expireAt --collection-group=usage --enable-ttl`
   `gcloud firestore fields ttls update expiresAt --collection-group=nonces --enable-ttl`
   `gcloud firestore fields ttls update expireAt --collection-group=tickets --enable-ttl`
10. Deploy: `firebase deploy --only functions,firestore:rules,storage` (from the project root).

## Local testing
Put `ENFORCE_INTEGRITY=false` in `functions/.env.local`, then `npm run serve`.
Use a real release build from Play (internal testing track) to test integrity and billing.

## Client contract
- Error messages the app must handle: `integrity-required` (re-run the check), `daily-limit-reached` (show paywall), `sign-in-required` (Google sign-in before billing), `document-too-long`, `ai-unavailable`.
- Purchases must be launched with `applicationUserName` = `accountId` from `getBillingAccountId`.
- The client only reads `users/{uid}`; it can never write it.
