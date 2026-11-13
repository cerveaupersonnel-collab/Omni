import { randomBytes } from "crypto";

import { Timestamp } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { google } from "googleapis";

import { baseOptions, NONCE_TTL_MS, PACKAGE_NAME, PLAY_CERT_SHA256_DIGESTS } from "./config";
import { db } from "./firebase";
import { requireAuth } from "./guards";

const NONCE_RE = /^[A-Za-z0-9_-]{20,100}$/;

function normalizeDigest(value: string): string {
  const cleaned = value.replace(/[:\s]/g, "");
  return /^[0-9a-fA-F]{64}$/.test(cleaned) ? Buffer.from(cleaned, "hex").toString("base64url") : cleaned;
}

/** Step 1: the client asks for a one-time nonce bound to its uid. */
export const getIntegrityNonce = onCall(baseOptions, async (req) => {
  const uid = requireAuth(req);
  const nonce = randomBytes(32).toString("base64url");
  await db.doc(`nonces/${nonce}`).set({
    uid,
    expiresAt: Timestamp.fromMillis(Date.now() + NONCE_TTL_MS),
  });
  return { nonce };
});

/**
 * Step 2: the client sends the Play Integrity token. The server decodes it with
 * Google and returns { ok }. ok=false means rooted / repackaged / unlicensed:
 * the app must show the blocking screen and exit.
 */
export const verifyIntegrity = onCall(baseOptions, async (req) => {
  const uid = requireAuth(req);
  const d = (req.data ?? {}) as { token?: unknown; nonce?: unknown };
  if (typeof d.token !== "string" || d.token.length < 20 || d.token.length > 20_000) {
    throw new HttpsError("invalid-argument", "Invalid token.");
  }
  if (typeof d.nonce !== "string" || !NONCE_RE.test(d.nonce)) {
    throw new HttpsError("invalid-argument", "Invalid nonce.");
  }
  const { token, nonce } = d as { token: string; nonce: string };

  // Consume the nonce exactly once.
  const nonceRef = db.doc(`nonces/${nonce}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(nonceRef);
    const expiresAt = snap.get("expiresAt") as Timestamp | undefined;
    if (!snap.exists || snap.get("uid") !== uid || !expiresAt || expiresAt.toMillis() < Date.now()) {
      throw new HttpsError("failed-precondition", "nonce-invalid");
    }
    tx.delete(nonceRef);
  });

  const allowedDigests = PLAY_CERT_SHA256_DIGESTS.value()
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean)
    .map(normalizeDigest);
  if (allowedDigests.length === 0) {
    logger.error("PLAY_CERT_SHA256_DIGESTS is not configured");
    throw new HttpsError("failed-precondition", "server-misconfigured");
  }

  let payload;
  try {
    const auth = new google.auth.GoogleAuth({ scopes: ["https://www.googleapis.com/auth/playintegrity"] });
    const api = google.playintegrity({ version: "v1", auth });
    const res = await api.v1.decodeIntegrityToken({
      packageName: PACKAGE_NAME,
      requestBody: { integrityToken: token },
    });
    payload = res.data.tokenPayloadExternal;
  } catch (err) {
    logger.error("decodeIntegrityToken failed", { err: err instanceof Error ? err.message : String(err) });
    throw new HttpsError("unavailable", "integrity-service-unavailable");
  }

  const reasons: string[] = [];
  const request = payload?.requestDetails;
  const timestamp = Number(request?.timestampMillis ?? 0);
  if (request?.nonce !== nonce) reasons.push("nonce-mismatch");
  if (request?.requestPackageName !== PACKAGE_NAME) reasons.push("package-mismatch");
  if (!timestamp || Math.abs(Date.now() - timestamp) > 10 * 60 * 1000) reasons.push("stale-token");
  if (payload?.appIntegrity?.appRecognitionVerdict !== "PLAY_RECOGNIZED") reasons.push("app-not-recognized");
  const digests = payload?.appIntegrity?.certificateSha256Digest ?? [];
  if (!digests.some((x) => allowedDigests.includes(x))) reasons.push("certificate-mismatch");
  if (!(payload?.deviceIntegrity?.deviceRecognitionVerdict ?? []).includes("MEETS_DEVICE_INTEGRITY")) {
    reasons.push("device-not-trusted");
  }
  if (payload?.accountDetails?.appLicensingVerdict !== "LICENSED") reasons.push("not-licensed");

  const ok = reasons.length === 0;
  await db.doc(`integrity/${uid}`).set({
    ok,
    reasons,
    verifiedAt: Timestamp.now(),
  });
  if (!ok) logger.warn("Integrity check failed", { uid, reasons });
  return { ok };
});
