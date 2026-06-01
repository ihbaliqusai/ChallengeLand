package net.androidgaming.millionaire2024;

import android.view.View;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.util.Random;

/**
 * Drives the four contestant podiums shown in the offline (single-player) game.
 * Slot 0 is the human player; slots 1-3 are AI bots that answer each question
 * with a probability that depends on the question difficulty and their skill.
 * The podium status is shown as an icon: a clock while waiting, then a green
 * check (correct) or a red cross (wrong) once the round is revealed.
 */
final class GameOfflineContestantsController {
    private static final int POINTS_PER_CORRECT = 100;

    private static final String[] MALE_NAMES = {
            "خالد", "طارق", "فهد", "ماجد", "ياسر", "نواف", "سعد", "زياد", "بدر"
    };
    private static final String[] FEMALE_NAMES = {
            "فاطمة", "نورة", "سارة", "ريم", "هند", "لمى", "دانة", "جود"
    };

    private final GameActivity activity;
    private final Random random = new Random();

    private final String[] names = new String[4];
    private final int[] scores = new int[4];
    private final int[] intelligence = new int[4];
    private final boolean[] roundCorrect = new boolean[4];

    private final TextView[] scoreViews = new TextView[4];
    private final TextView[] nameViews = new TextView[4];
    private final ImageView[] statusViews = new ImageView[4];
    private LinearLayout row;
    private boolean active = false;

    GameOfflineContestantsController(GameActivity activity) {
        this.activity = activity;
    }

    boolean isActive() {
        return active;
    }

    /** Wires the podium views, assigns names/skills and reveals the row. */
    void setup() {
        row = activity.findViewById(R.id.contestantsRow);
        int[] scoreIds = {R.id.contestant0Score, R.id.contestant1Score, R.id.contestant2Score, R.id.contestant3Score};
        int[] nameIds = {R.id.contestant0Name, R.id.contestant1Name, R.id.contestant2Name, R.id.contestant3Name};
        int[] statusIds = {R.id.contestant0Status, R.id.contestant1Status, R.id.contestant2Status, R.id.contestant3Status};
        for (int i = 0; i < 4; i++) {
            scoreViews[i] = activity.findViewById(scoreIds[i]);
            nameViews[i] = activity.findViewById(nameIds[i]);
            statusViews[i] = activity.findViewById(statusIds[i]);
            scores[i] = 0;
        }

        names[0] = resolvePlayerName();
        names[1] = pick(MALE_NAMES, null);
        names[2] = pick(FEMALE_NAMES, null);
        names[3] = pick(MALE_NAMES, names[1]);
        for (int i = 1; i < 4; i++) {
            intelligence[i] = 48 + random.nextInt(42); // 48..89
        }

        for (int i = 0; i < 4; i++) {
            if (nameViews[i] != null) nameViews[i].setText(names[i]);
            if (scoreViews[i] != null) scoreViews[i].setText("0");
            setStatusIcon(i, R.drawable.ic_status_waiting);
        }

        active = true;
        if (row != null) row.setVisibility(View.VISIBLE);
        View namePlate = activity.findViewById(R.id.hostNamePlate);
        if (namePlate != null) namePlate.setVisibility(View.VISIBLE);
    }

    /**
     * Begins a new round. Everyone shows the waiting clock; the bots privately
     * lock their (predetermined) answer. {@code rightAnswer} is the displayed index 1-4.
     */
    void startRound(String questionLevel, int rightAnswer) {
        if (!active) return;
        for (int i = 0; i < 4; i++) {
            roundCorrect[i] = false;
            setStatusIcon(i, R.drawable.ic_status_waiting);
        }
        for (int i = 1; i < 4; i++) {
            roundCorrect[i] = rollCorrect(questionLevel, intelligence[i]);
        }
    }

    void markPlayerAnswered() {
        // The status icon stays "waiting" until the round is revealed.
    }

    /** Reveals the round: awards points and shows the correct/wrong icon for everyone. */
    void revealRound(boolean playerCorrect) {
        if (!active) return;
        roundCorrect[0] = playerCorrect;
        for (int i = 0; i < 4; i++) {
            if (roundCorrect[i]) {
                scores[i] += POINTS_PER_CORRECT;
                if (scoreViews[i] != null) scoreViews[i].setText(String.valueOf(scores[i]));
                setStatusIcon(i, R.drawable.ic_status_correct);
            } else {
                setStatusIcon(i, R.drawable.ic_status_wrong);
            }
        }
    }

    int playerScore() {
        return scores[0];
    }

    int playerRank() {
        int rank = 1;
        for (int i = 1; i < 4; i++) {
            if (scores[i] > scores[0]) rank++;
        }
        return rank;
    }

    boolean playerIsWinner() {
        for (int i = 1; i < 4; i++) {
            if (scores[i] > scores[0]) return false;
        }
        return true; // ties resolve in the player's favour
    }

    String leaderName() {
        int best = 0;
        for (int i = 1; i < 4; i++) {
            if (scores[i] > scores[best]) best = i;
        }
        return names[best];
    }

    String standingsLine() {
        if (playerIsWinner()) {
            return "أنت في الصدارة الآن";
        }
        return "المتصدّر: " + leaderName();
    }

    void release() {
        active = false;
    }

    private void setStatusIcon(int slot, int resId) {
        ImageView view = statusViews[slot];
        if (view != null) {
            view.setImageResource(resId);
        }
    }

    private String resolvePlayerName() {
        String name = activity.myName;
        if (name == null || name.trim().isEmpty()) {
            return "أنت";
        }
        name = name.trim();
        return name.length() > 9 ? name.substring(0, 9) : name;
    }

    private boolean rollCorrect(String level, int intel) {
        int base;
        switch (level == null ? "" : level) {
            case "0": base = 90; break;
            case "1": base = 78; break;
            case "2": base = 62; break;
            case "3": base = 48; break;
            default: base = 80; break;
        }
        int chance = base + (intel - 68) / 2;
        if (chance < 18) chance = 18;
        if (chance > 97) chance = 97;
        return random.nextInt(100) < chance;
    }

    private String pick(String[] pool, String avoid) {
        String chosen;
        int guard = 0;
        do {
            chosen = pool[random.nextInt(pool.length)];
        } while (chosen.equals(avoid) && guard++ < 8);
        return chosen;
    }
}
