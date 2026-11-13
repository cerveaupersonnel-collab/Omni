import { defineBoolean, defineSecret, defineString } from "firebase-functions/params";
import type { CallableOptions } from "firebase-functions/v2/https";

/** OpenAI key lives only in Secret Manager. Set with: firebase functions:secrets:set OPENAI_API_KEY */
export const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");
export const PLAY_CERT_SHA256_DIGESTS = defineString("PLAY_CERT_SHA256_DIGESTS", { default: "" });
export const ENFORCE_INTEGRITY = defineBoolean("ENFORCE_INTEGRITY", { default: true });

export const PACKAGE_NAME = "com.omni.omni";
export const REGION = "us-central1";
export const FREE_DAILY_LIMIT = 3;
/** Credits given back per feature per day when an operation is cancelled or fails. */
export const MAX_REFUNDS_PER_DAY = 3;
export const INTEGRITY_TTL_MS = 24 * 60 * 60 * 1000;
export const NONCE_TTL_MS = 5 * 60 * 1000;

export const PRODUCT_IDS: ReadonlySet<string> = new Set(["omni_pro_monthly", "omni_pro_yearly"]);

export const FEATURES = ["scan", "chat_pdf", "cleaner", "compressor", "vault"] as const;
export type Feature = (typeof FEATURES)[number];

/** Features whose work runs on-device; the client asks the server for permission first. */
export const CLIENT_FEATURES = ["scan", "cleaner", "compressor", "vault"] as const;
export type ClientFeature = (typeof CLIENT_FEATURES)[number];

export const baseOptions: CallableOptions = {
  region: REGION,
  enforceAppCheck: true,
  maxInstances: 100,
};
