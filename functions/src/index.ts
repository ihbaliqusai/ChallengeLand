import * as admin from "firebase-admin";

// تهيئة Firebase Admin مرة واحدة عند الإقلاع
admin.initializeApp();

export { onMatchmakingWrite, cleanupStaleQueue } from "./matchmaking";
