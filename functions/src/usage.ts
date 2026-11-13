import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import {
  baseOptions,
  CLIENT_FEATURES,
  ClientFeature,
  FEATURES,
  Feature,
  FREE_DAILY_LIMIT,
  MAX_REFUNDS_PER_DAY,
} from "./config";
import { db } from "./firebase";
import { requireAuth, requireIntegrity } from "./guards";

function today(): string {
  return new Date().toISOString().slice(0, 10); // UTC day
}

export async function isPro(uid: string): Promise<boolean> {
  const snap = await db.doc(`users/${uid}`).get();
  if (!snap.exists) return false;
  const expires = snap.get("proExpiresAt") as Timestamp | undefined;
  return snap.get("isPro") === true && !!expires && expires.toMillis() > Date.now();
}

export interface UseResult {
  pro: boolean;
  remaining: number | null;
}

/** Atomically spends one free use. Pro users are unlimited. */
export async function consumeUse(uid: string, feature: Feature): Promise<UseResult> {
  if (await isPro(uid)) return { pro: true, remaining: null };

  const day = today();
  const ref = db.doc(`usage/${uid}_${day}`);
  const remaining = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const used = (snap.get(`counts.${feature}`) as number | undefined) ?? 0;
    if (used >= FREE_DAILY_LIMIT) {
      throw new HttpsError("resource-exhausted", "daily-limit-reached");
    }
    tx.set(
      ref,
      {
        uid,
        day,
        counts: { [feature]: used + 1 },
        updatedAt: FieldValue.serverTimestamp(),
        expireAt: Timestamp.fromMillis(Date.now() + 3 * 24 * 60 * 60 * 1000),
      },
      { merge: true },
    );
    return FREE_DAILY_LIMIT - used - 1;
  });
  return { pro: false, remaining };
}

/** Gives a use back when the work failed because of us (e.g. OpenAI outage). */
export async function refundUse(uid: string, feature: Feature, wasPro: boolean): Promise<void> {
  if (wasPro) return;
  const ref = db.doc(`usage/${uid}_${today()}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const used = (snap.get(`counts.${feature}`) as number | undefined) ?? 0;
    if (used > 0) {
      tx.set(ref, { counts: { [feature]: used - 1 } }, { merge: true });
    }
  });
}

/**
 * Reserves one free use before an on-device operation. The client must call
 * finishFeatureUse afterwards: success keeps the use, cancel/failure gives it back
 * (limited to MAX_REFUNDS_PER_DAY per feature so the refund cannot be abused).
 */
export const beginFeatureUse = onCall(baseOptions, async (req) => {
  const uid = requireAuth(req);
  await requireIntegrity(uid);
  const feature = (req.data as { feature?: unknown } | undefined)?.feature;
  if (typeof feature !== "string" || !(CLIENT_FEATURES as readonly string[]).includes(feature)) {
    throw new HttpsError("invalid-argument", "Unknown feature.");
  }
  const usage = await consumeUse(uid, feature as ClientFeature);
  if (usage.pro) return { pro: true, remaining: null, ticketId: null };

  const ticket = db.collection("tickets").doc();
  await ticket.set({
    uid,
    feature,
    day: today(),
    state: "reserved",
    createdAt: FieldValue.serverTimestamp(),
    expireAt: Timestamp.fromMillis(Date.now() + 2 * 24 * 60 * 60 * 1000),
  });
  return { pro: false, remaining: usage.remaining, ticketId: ticket.id };
});

export const finishFeatureUse = onCall(baseOptions, async (req) => {
  const uid = requireAuth(req);
  const d = (req.data ?? {}) as { ticketId?: unknown; success?: unknown };
  if (typeof d.ticketId !== "string" || !/^[A-Za-z0-9]{10,40}$/.test(d.ticketId) || typeof d.success !== "boolean") {
    throw new HttpsError("invalid-argument", "ticketId and success are required.");
  }
  const ticketId = d.ticketId;
  const success = d.success;

  const state = await db.runTransaction(async (tx) => {
    const tref = db.doc(`tickets/${ticketId}`);
    const t = await tx.get(tref);
    if (!t.exists || t.get("uid") !== uid) throw new HttpsError("not-found", "ticket-not-found");
    const current = t.get("state") as string;
    if (current !== "reserved") return current; // idempotent

    if (success) {
      tx.update(tref, { state: "committed" });
      return "committed";
    }
    const feature = t.get("feature") as string;
    const uref = db.doc(`usage/${uid}_${t.get("day")}`);
    const usageSnap = await tx.get(uref);
    const used = (usageSnap.get(`counts.${feature}`) as number | undefined) ?? 0;
    const refunds = (usageSnap.get(`refunds.${feature}`) as number | undefined) ?? 0;
    if (used <= 0 || refunds >= MAX_REFUNDS_PER_DAY) {
      tx.update(tref, { state: "cancelled-no-refund" });
      return "cancelled-no-refund";
    }
    tx.set(uref, { counts: { [feature]: used - 1 }, refunds: { [feature]: refunds + 1 } }, { merge: true });
    tx.update(tref, { state: "cancelled" });
    return "cancelled";
  });
  return { state };
});

export const getUsageStatus = onCall(baseOptions, async (req) => {
  const uid = requireAuth(req);
  const [pro, usage] = await Promise.all([isPro(uid), db.doc(`usage/${uid}_${today()}`).get()]);
  const used: Record<string, number> = {};
  for (const f of FEATURES) {
    used[f] = (usage.get(`counts.${f}`) as number | undefined) ?? 0;
  }
  return { pro, limit: FREE_DAILY_LIMIT, used };
});
