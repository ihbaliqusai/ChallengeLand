import * as admin from "firebase-admin";
import { logger } from "firebase-functions";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";

// ─── أنواع البيانات ───────────────────────────────────────────

interface QueueEntry {
  uid: string;
  username: string;
  rating: number;
  mode: string;
  status: "waiting" | "matched" | "cancelled";
  enteredAt: admin.firestore.Timestamp;
  matchedSessionId: string | null;
}

// ─── منطق الفوارق بناءً على وقت الانتظار ───────────────────────

const RATING_BRACKETS = [
  { maxWaitMs: 30_000,   maxDiff: 200 },   // < 30 ث
  { maxWaitMs: 60_000,   maxDiff: 500 },   // < 60 ث
  { maxWaitMs: Infinity, maxDiff: Infinity }, // أي لاعب
];

function ratingBracket(waitMs: number): number {
  for (const b of RATING_BRACKETS) {
    if (waitMs < b.maxWaitMs) return b.maxDiff;
  }
  return Infinity;
}

// ─── عدد اللاعبين المطلوبين لكل نمط ────────────────────────────

const MODE_REQUIREMENTS: Record<string, number> = {
  quick1v1: 2,
  teams2v2: 4,
  teams3v3: 6,
  party:    4,  // الحد الأدنى؛ يمكن البدء بـ 4
};

// ─── Cloud Function: تشغيل عند كل كتابة في طابور المطابقة ───────

export const onMatchmakingWrite = onDocumentWritten(
  "matchmaking_queue/{uid}",
  async (event) => {
    const after = event.data?.after.data() as QueueEntry | undefined;

    // نتجاهل الحذف أو إذا لم يعد اللاعب في حالة انتظار
    if (!after || after.status !== "waiting") return;

    const db    = admin.firestore();
    const uid   = event.params["uid"] as string;
    const now   = Date.now();
    const { rating, mode } = after;
    const myWaitMs = now - (after.enteredAt?.toMillis() ?? now);

    // جلب كل المنتظرين بنفس النمط
    const snapshot = await db
      .collection("matchmaking_queue")
      .where("mode",   "==", mode)
      .where("status", "==", "waiting")
      .get();

    // فلترة المرشحين بناءً على فارق التقييم
    const candidates = snapshot.docs
      .filter((doc) => doc.id !== uid)
      .map((doc) => ({ id: doc.id, ...(doc.data() as QueueEntry) }))
      .filter((c) => {
        const cWaitMs        = now - (c.enteredAt?.toMillis() ?? now);
        // نستخدم الفارق الأوسع بين اللاعبين (يصبح الانتظار الأطول أكثر مرونة)
        const effectiveDiff  = Math.max(ratingBracket(myWaitMs), ratingBracket(cWaitMs));
        return Math.abs(c.rating - rating) <= effectiveDiff;
      });

    const required = MODE_REQUIREMENTS[mode] ?? 2;

    if (mode === "quick1v1") {
      // ─ لاعب ضد لاعب: أقرب تقييم يفوز ─
      if (candidates.length === 0) return;

      candidates.sort(
        (a, b) => Math.abs(a.rating - rating) - Math.abs(b.rating - rating),
      );

      await _createMatchSafe(db, [uid, candidates[0].id], mode);
    } else {
      // ─ أنماط الفرق: FIFO بعد اكتمال العدد ─
      if (candidates.length + 1 < required) return;

      // ترتيب بحسب وقت الدخول (الأقدم أولاً)
      candidates.sort(
        (a, b) => (a.enteredAt?.toMillis() ?? 0) - (b.enteredAt?.toMillis() ?? 0),
      );

      const pickedUids = [uid, ...candidates.slice(0, required - 1).map((c) => c.id)];
      await _createMatchSafe(db, pickedUids, mode);
    }
  },
);

// ─── إنشاء جلسة اللعب بشكل آمن (Transaction) ───────────────────

async function _createMatchSafe(
  db: admin.firestore.Firestore,
  uids: string[],
  mode: string,
): Promise<void> {
  try {
    await _createMatch(db, uids, mode);
    logger.info(`Match created for [${uids.join(", ")}] mode=${mode}`);
  } catch (err) {
    // تعارض: لاعب سبق وتمت مطابقته من دالة موازية — مقبول تماماً
    logger.warn("Match creation skipped (race condition):", err);
  }
}

async function _createMatch(
  db: admin.firestore.Firestore,
  uids: string[],
  mode: string,
): Promise<void> {
  const sessionRef = db.collection("game_sessions").doc();
  const sessionId  = sessionRef.id;

  const playerScores: Record<string, number> = {};
  uids.forEach((u) => { playerScores[u] = 0; });

  const session = {
    id:                   sessionId,
    mode,
    playerIds:            uids,
    playerScores,
    teamScores:           {},
    questionIds:          [],
    currentQuestionIndex: 0,
    status:               "active",
    timerSeconds:         60,
    startedAt:            admin.firestore.FieldValue.serverTimestamp(),
    finishedAt:           null,
    winnerId:             null,
    winningTeamId:        null,
    roomId:               null,
  };

  await db.runTransaction(async (tx) => {
    const queueRefs = uids.map((u) =>
      db.collection("matchmaking_queue").doc(u),
    );
    const docs = await Promise.all(queueRefs.map((ref) => tx.get(ref)));

    // التحقق أن جميع اللاعبين لا يزالون ينتظرون
    for (const doc of docs) {
      const data = doc.data() as QueueEntry | undefined;
      if (!data || data.status !== "waiting") {
        throw new Error(`player ${doc.id} no longer waiting`);
      }
    }

    tx.set(sessionRef, session);
    queueRefs.forEach((ref) =>
      tx.update(ref, {
        status:           "matched",
        matchedSessionId: sessionId,
      }),
    );
  });
}

// ─── Cloud Function: تنظيف الطابور كل 5 دقائق ──────────────────

export const cleanupStaleQueue = onSchedule("every 5 minutes", async () => {
  const db     = admin.firestore();
  // المدخلات الأقدم من 10 دقائق في حالة انتظار → يُحذف
  const cutoff = new Date(Date.now() - 10 * 60 * 1000);

  const snapshot = await db
    .collection("matchmaking_queue")
    .where("status",    "==", "waiting")
    .where("enteredAt", "<",  admin.firestore.Timestamp.fromDate(cutoff))
    .get();

  if (snapshot.empty) return;

  const batch = db.batch();
  snapshot.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();

  logger.info(`Removed ${snapshot.size} stale matchmaking entries`);
});
