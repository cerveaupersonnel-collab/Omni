import { getAuth } from "firebase-admin/auth";
import { onCall } from "firebase-functions/v2/https";

import { baseOptions } from "./config";
import { db } from "./firebase";
import { requireAuth } from "./guards";

async function deleteWhereUid(collection: string, uid: string): Promise<void> {
  const snap = await db.collection(collection).where("uid", "==", uid).get();
  const writer = db.bulkWriter();
  snap.docs.forEach((d) => void writer.delete(d.ref));
  await writer.close();
}

/** In-app account deletion (Google Play "Account deletion" policy): erases all server data, then the auth user. */
export const deleteAccount = onCall(baseOptions, async (req) => {
  const uid = requireAuth(req);
  await Promise.all(["usage", "tickets", "purchaseTokens", "nonces"].map((c) => deleteWhereUid(c, uid)));
  await Promise.all([db.doc(`users/${uid}`).delete(), db.doc(`integrity/${uid}`).delete()]);
  await getAuth().deleteUser(uid);
  return { deleted: true };
});
