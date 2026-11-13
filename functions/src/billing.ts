import { createHash } from "crypto";

import { getAuth } from "firebase-admin/auth";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { onMessagePublished } from "firebase-functions/v2/pubsub";
import { androidpublisher_v3, google } from "googleapis";

import { baseOptions, PACKAGE_NAME, PRODUCT_IDS, REGION } from "./config";
import { db } from "./firebase";
import { requireAuth, requireIntegrity } from "./guards";

type Subscription = androidpublisher_v3.Schema$SubscriptionPurchaseV2;

const ACCESS_STATES: ReadonlySet<string> = new Set([
  "SUBSCRIPTION_STATE_ACTIVE",
  "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
  "SUBSCRIPTION_STATE_CANCELED", // cancelled but paid until expiry
]);

const sha256 = (value: string): string => createHash("sha256").update(value).digest("hex");

function publisher(): androidpublisher_v3.Androidpublisher {
  const auth = new google.auth.GoogleAuth({ scopes: ["https://www.googleapis.com/auth/androidpublisher"] });
  return google.androidpublisher({ version: "v3", auth });
}

async function fetchSubscription(token: string): Promise<Subscription> {
  const res = await publisher().purchases.subscriptionsv2.get({ packageName: PACKAGE_NAME, token });
  return res.data;
}

function proItem(sub: Subscription): androidpublisher_v3.Schema$SubscriptionPurchaseLineItem | undefined {
  return sub.lineItems?.find((li) => !!li.productId && PRODUCT_IDS.has(li.productId));
}

/** Writes the entitlement. Only the server can write users/{uid}. */
async function applyEntitlement(uid: string, tokenHash: string, sub: Subscription): Promise<boolean> {
  const item = proItem(sub);
  const expiry = item?.expiryTime ? new Date(item.expiryTime) : null;
  const active =
    !!item && !!expiry && expiry.getTime() > Date.now() && ACCESS_STATES.has(sub.subscriptionState ?? "");

  const ref = db.doc(`users/${uid}`);
  const current = await ref.get();
  // An old, inactive token must never overwrite a newer active subscription.
  if (!active && current.get("isPro") === true && current.get("proTokenHash") !== tokenHash) {
    return true;
  }

  await ref.set(
    {
      isPro: active,
      proExpiresAt: expiry ? Timestamp.fromDate(expiry) : null,
      proProductId: item?.productId ?? null,
      proState: sub.subscriptionState ?? null,
      proTokenHash: tokenHash,
      proUpdatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  return active;
}

async function acknowledgeIfNeeded(token: string, sub: Subscription): Promise<void> {
  const productId = proItem(sub)?.productId;
  if (sub.acknowledgementState !== "ACKNOWLEDGEMENT_STATE_PENDING" || !productId) return;
  try {
    await publisher().purchases.subscriptions.acknowledge({
      packageName: PACKAGE_NAME,
      subscriptionId: productId,
      token,
      requestBody: {},
    });
  } catch (err) {
    // Play retries via RTDN; unacknowledged purchases are refunded after 3 days.
    logger.error("Acknowledge failed", { err: err instanceof Error ? err.message : String(err) });
  }
}

/** Subscriptions are bound to a permanent (Google) account so they survive a reinstall. */
async function requirePermanentAccount(uid: string): Promise<void> {
  const user = await getAuth().getUser(uid);
  if (user.providerData.length === 0) {
    throw new HttpsError("failed-precondition", "sign-in-required");
  }
}

/** The client passes this as the purchase's obfuscated account id (applicationUserName). */
export const getBillingAccountId = onCall(baseOptions, async (req) => {
  const uid = requireAuth(req);
  await requirePermanentAccount(uid);
  return { accountId: sha256(uid) };
});

/** Called after a purchase and for every restored purchase ("Restore Purchase"). */
export const verifyPurchase = onCall(baseOptions, async (req) => {
  const uid = requireAuth(req);
  await requireIntegrity(uid);
  await requirePermanentAccount(uid);

  const d = (req.data ?? {}) as { purchaseToken?: unknown };
  if (typeof d.purchaseToken !== "string" || d.purchaseToken.length < 10 || d.purchaseToken.length > 4000) {
    throw new HttpsError("invalid-argument", "Invalid purchase token.");
  }
  const token = d.purchaseToken;
  const tokenHash = sha256(token);

  let sub: Subscription;
  try {
    sub = await fetchSubscription(token);
  } catch (err) {
    logger.warn("Play lookup failed", { uid, err: err instanceof Error ? err.message : String(err) });
    throw new HttpsError("invalid-argument", "purchase-not-found");
  }

  if (!proItem(sub)) {
    throw new HttpsError("invalid-argument", "unknown-product");
  }
  if (sub.externalAccountIdentifiers?.obfuscatedExternalAccountId !== sha256(uid)) {
    throw new HttpsError("permission-denied", "purchase-belongs-to-another-account");
  }

  const tokenRef = db.doc(`purchaseTokens/${tokenHash}`);
  const owner = await tokenRef.get();
  if (owner.exists && owner.get("uid") !== uid) {
    throw new HttpsError("permission-denied", "purchase-belongs-to-another-account");
  }
  if (!owner.exists) {
    await tokenRef.set({ uid, createdAt: FieldValue.serverTimestamp() });
  }

  const active = await applyEntitlement(uid, tokenHash, sub);
  if (active) await acknowledgeIfNeeded(token, sub);

  if (sub.linkedPurchaseToken) {
    await db.doc(`purchaseTokens/${sha256(sub.linkedPurchaseToken)}`).delete().catch(() => undefined);
  }

  const expiry = proItem(sub)?.expiryTime ?? null;
  return { isPro: active, expiresAt: expiry, productId: proItem(sub)?.productId ?? null };
});

interface RtdnMessage {
  packageName?: string;
  testNotification?: unknown;
  subscriptionNotification?: { purchaseToken?: string };
  voidedPurchaseNotification?: { purchaseToken?: string };
}

/** Google Play Real-time Developer Notifications (Pub/Sub topic "play-rtdn"). */
export const playBillingWebhook = onMessagePublished({ topic: "play-rtdn", region: REGION }, async (event) => {
  let msg: RtdnMessage;
  try {
    msg = event.data.message.json as RtdnMessage;
  } catch {
    logger.warn("RTDN: invalid JSON");
    return;
  }
  if (!msg || msg.packageName !== PACKAGE_NAME) return;
  if (msg.testNotification) {
    logger.info("RTDN test notification received");
    return;
  }

  const token = msg.subscriptionNotification?.purchaseToken ?? msg.voidedPurchaseNotification?.purchaseToken;
  if (!token) return;
  const tokenHash = sha256(token);

  const owner = await db.doc(`purchaseTokens/${tokenHash}`).get();
  const uid = owner.get("uid") as string | undefined;
  if (!uid) {
    // Not linked yet: the app will link it through verifyPurchase.
    logger.info("RTDN for unlinked token");
    return;
  }

  if (msg.voidedPurchaseNotification) {
    const user = await db.doc(`users/${uid}`).get();
    if (user.get("proTokenHash") === tokenHash) {
      await db.doc(`users/${uid}`).set(
        { isPro: false, proState: "VOIDED", proUpdatedAt: FieldValue.serverTimestamp() },
        { merge: true },
      );
    }
    return;
  }

  const sub = await fetchSubscription(token); // errors trigger a Pub/Sub retry
  const active = await applyEntitlement(uid, tokenHash, sub);
  if (active) await acknowledgeIfNeeded(token, sub);
});
