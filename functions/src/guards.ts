import { Timestamp } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

import { ENFORCE_INTEGRITY, INTEGRITY_TTL_MS } from "./config";
import { db } from "./firebase";

export function requireAuth(req: { auth?: { uid: string } }): string {
  const uid = req.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  return uid;
}

/**
 * Blocks callers whose device/app has not passed a Play Integrity check in the
 * last 24h. The client reacts to the "integrity-required" message by re-running
 * the check (getIntegrityNonce -> verifyIntegrity).
 */
export async function requireIntegrity(uid: string): Promise<void> {
  if (!ENFORCE_INTEGRITY.value()) return;
  const snap = await db.doc(`integrity/${uid}`).get();
  const verifiedAt = snap.get("verifiedAt") as Timestamp | undefined;
  if (snap.get("ok") !== true || !verifiedAt || Date.now() - verifiedAt.toMillis() > INTEGRITY_TTL_MS) {
    throw new HttpsError("failed-precondition", "integrity-required");
  }
}
