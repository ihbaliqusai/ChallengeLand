package com.qi7bali.landchallengeonline;

import android.app.Activity;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.widget.Toast;
import org.json.JSONArray;
import org.json.JSONObject;

/** Records real background intervals; focus changes and app dialogs do not start one. */
final class GameBackgroundGuard {
    interface Host {
        String backgroundQuestionKey();
        boolean applyBackgroundPenalty(String question, int violations);
    }

    private final Activity activity;
    private final Host host;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private BackgroundAnswerPolicy policy;
    private String storageKey;
    private boolean applying;
    private boolean background;
    private boolean destroyed;
    private final Runnable deadline = () -> {
        policy.evaluate(SystemClock.elapsedRealtime(), System.currentTimeMillis());
        save();
        enforce(); // Submit online skips when possible; resume also reconciles suspended processes.
    };

    GameBackgroundGuard(Activity activity, Host host) {
        this.activity = activity;
        this.host = host;
    }

    private void load() {
        String key = "background_answer_v1:" + NativeProgression.matchId(activity);
        if (key.equals(storageKey)) return;
        storageKey = key;
        policy = new BackgroundAnswerPolicy();
        try {
            JSONObject json = new JSONObject(ProgressionAccount.preferences(activity).getString(key, "{}"));
            policy.violations = Math.min(BackgroundAnswerPolicy.MAX_VIOLATIONS, json.optInt("violations"));
            policy.awayQuestion = json.optString("awayQuestion");
            policy.awayElapsed = json.optLong("awayElapsed");
            policy.awayWall = json.optLong("awayWall");
            policy.pendingQuestion = json.optString("pendingQuestion");
            policy.notifiedViolations = json.optInt("notifiedViolations");
            JSONArray questions = json.optJSONArray("questions");
            if (questions != null) for (int i = 0; i < questions.length(); i++)
                policy.penalizedQuestions.add(questions.optString(i));
        } catch (org.json.JSONException error) {
            throw new IllegalStateException("Cannot restore background answer protection", error);
        }
    }

    private void save() {
        if (!NativeProgression.activeAccount(activity)) return;
        try {
            JSONObject json = new JSONObject();
            json.put("violations", policy.violations);
            json.put("awayQuestion", policy.awayQuestion);
            json.put("awayElapsed", policy.awayElapsed);
            json.put("awayWall", policy.awayWall);
            json.put("pendingQuestion", policy.pendingQuestion);
            json.put("notifiedViolations", policy.notifiedViolations);
            json.put("questions", new JSONArray(policy.penalizedQuestions));
            ProgressionAccount.commitOrRollback(ProgressionAccount.preferences(activity),
                    ProgressionAccount.preferences(activity).edit().putString(storageKey, json.toString()));
        } catch (org.json.JSONException error) {
            throw new IllegalStateException("Cannot save background answer protection", error);
        }
    }

    void onStop() {
        if (activity.isFinishing() || activity.isChangingConfigurations()
                || !NativeProgression.activeAccount(activity)) return;
        load();
        background = true;
        policy.leave(host.backgroundQuestionKey(), SystemClock.elapsedRealtime(), System.currentTimeMillis());
        save();
        handler.removeCallbacks(deadline);
        if (!policy.awayQuestion.isEmpty()) handler.postDelayed(deadline, BackgroundAnswerPolicy.GRACE_MS + 1L);
    }

    boolean onResume() {
        background = false;
        handler.removeCallbacks(deadline);
        if (!NativeProgression.activeAccount(activity)) return false;
        load();
        policy.resume(SystemClock.elapsedRealtime(), System.currentTimeMillis());
        boolean showWarning = policy.violations == 2 && policy.notifiedViolations < 2;
        if (policy.violations > policy.notifiedViolations) {
            policy.notifiedViolations = policy.violations;
        }
        save();
        if (showWarning) Toast.makeText(activity,
                "غادرت اللعبة لأكثر من 10 ثوانٍ أثناء الإجابة مرتين. أُغلق السؤال، وتكرار ذلك مرة ثالثة ينهي مشاركتك.",
                Toast.LENGTH_LONG).show();
        return enforce();
    }

    boolean enforce() {
        if (destroyed || applying || !NativeProgression.activeAccount(activity)) return false;
        load();
        if (policy.pendingQuestion.isEmpty() && !policy.disqualified()) return false;
        applying = true;
        try { return host.applyBackgroundPenalty(policy.pendingQuestion, policy.violations); }
        finally { applying = false; }
    }

    void acknowledge() {
        if (policy == null || !NativeProgression.activeAccount(activity)) return;
        policy.acknowledge();
        save();
    }

    boolean isBackground() { return background; }

    void onDestroy() {
        destroyed = true;
        handler.removeCallbacks(deadline);
    }
}
