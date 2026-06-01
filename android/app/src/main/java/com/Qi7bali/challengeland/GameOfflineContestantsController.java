package net.androidgaming.millionaire2024;

import android.graphics.Color;
import android.graphics.Typeface;
import android.text.TextUtils;
import android.util.DisplayMetrics;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import androidx.core.content.res.ResourcesCompat;

import java.util.HashSet;
import java.util.Random;
import java.util.Set;

/**
 * Drives the contestant podiums shown in the offline (single-player) game.
 * Slot 0 is the human player (using the character chosen on the setup screen);
 * the remaining slots are AI bots. The podiums are built dynamically so 2-8
 * players fit in one row, shrinking as the count grows. The podium status is an
 * icon: a clock while waiting, then a green check (correct) or red cross (wrong)
 * once the round is revealed.
 */
final class GameOfflineContestantsController {
    private static final int POINTS_PER_CORRECT = 100;

    private static final int[] CHARACTER_DRAWABLES = {
            R.drawable.game_contestant_glasses,
            R.drawable.game_contestant_waving,
            R.drawable.game_contestant_female,
            R.drawable.game_contestant_green
    };
    private static final int FEMALE_CHARACTER_INDEX = 2;
    /** Width / height of the contestant artwork (1086 x 2550). */
    private static final float ART_ASPECT = 1086f / 2550f;

    // Net "distance from podium bottom" as a fraction of the rendered art height,
    // measured from the baked-in panels of the artwork.
    private static final float SCORE_MARGIN_F = 0.297f;
    private static final float NAME_MARGIN_F = 0.2035f;
    private static final float STATUS_MARGIN_F = 0.0865f;

    private static final String[] MALE_NAMES = {
            "خالد", "طارق", "فهد", "ماجد", "ياسر", "نواف", "سعد", "زياد", "بدر", "عمر"
    };
    private static final String[] FEMALE_NAMES = {
            "فاطمة", "نورة", "سارة", "ريم", "هند", "لمى", "دانة", "جود"
    };

    private final GameActivity activity;
    private final Random random = new Random();

    private int count = 4;
    private String[] names;
    private int[] scores;
    private int[] intelligence;
    private boolean[] roundCorrect;

    private TextView[] scoreViews;
    private TextView[] nameViews;
    private ImageView[] statusViews;
    private LinearLayout row;
    private Typeface balooFont;
    private boolean active = false;

    GameOfflineContestantsController(GameActivity activity) {
        this.activity = activity;
    }

    boolean isActive() {
        return active;
    }

    /** Builds {@code playerCount} podiums; slot 0 uses {@code characterIndex}. */
    void setup(int playerCount, int characterIndex) {
        count = Math.max(2, Math.min(8, playerCount));
        characterIndex = ((characterIndex % 4) + 4) % 4;

        names = new String[count];
        scores = new int[count];
        intelligence = new int[count];
        roundCorrect = new boolean[count];
        scoreViews = new TextView[count];
        nameViews = new TextView[count];
        statusViews = new ImageView[count];

        try {
            balooFont = ResourcesCompat.getFont(activity, R.font.baloo);
        } catch (Exception ignored) {
            balooFont = null;
        }

        names[0] = resolvePlayerName();
        Set<String> used = new HashSet<>();
        used.add(names[0]);
        for (int i = 1; i < count; i++) {
            intelligence[i] = 48 + random.nextInt(42); // 48..89
            int charIdx = (characterIndex + i) % 4;
            names[i] = pickName(charIdx == FEMALE_CHARACTER_INDEX, used);
            used.add(names[i]);
        }

        buildPodiums(characterIndex);

        active = true;
        if (row != null) row.setVisibility(View.VISIBLE);
        View namePlate = activity.findViewById(R.id.hostNamePlate);
        if (namePlate != null) namePlate.setVisibility(View.VISIBLE);
    }

    private void buildPodiums(int characterIndex) {
        row = activity.findViewById(R.id.contestantsRow);
        if (row == null) {
            return;
        }
        row.removeAllViews();

        final DisplayMetrics metrics = activity.getResources().getDisplayMetrics();
        final float density = metrics.density;
        final float screenWidthDp = metrics.widthPixels / density;
        final float paddingStartDp = 84f; // leave room for the host on the left
        final float paddingEndDp = 20f;
        row.setPadding(px(paddingStartDp, density), 0, px(paddingEndDp, density), 0);

        final float availableDp = Math.max(120f, screenWidthDp - paddingStartDp - paddingEndDp);
        float imageWidthDp = (availableDp / count) - 6f;
        if (imageWidthDp > 80f) imageWidthDp = 80f;
        if (imageWidthDp < 38f) imageWidthDp = 38f;
        final float h = imageWidthDp / ART_ASPECT; // rendered art (and panel) height in dp

        for (int i = 0; i < count; i++) {
            FrameLayout cell = new FrameLayout(activity);
            cell.setLayoutParams(new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f));
            cell.setClipChildren(false);
            cell.setClipToPadding(false);

            ImageView art = new ImageView(activity);
            FrameLayout.LayoutParams artParams =
                    new FrameLayout.LayoutParams(px(imageWidthDp, density), px(h, density));
            artParams.gravity = Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL;
            art.setLayoutParams(artParams);
            art.setScaleType(ImageView.ScaleType.FIT_CENTER);
            art.setImageResource(CHARACTER_DRAWABLES[(characterIndex + i) % 4]);
            cell.addView(art);

            TextView score = makeLabel(0.24f * h, 0.11f * h, SCORE_MARGIN_F * h,
                    "0", 0.075f * h, "#61FF39", density);
            cell.addView(score);
            scoreViews[i] = score;

            TextView name = makeLabel(0.30f * h, 0.085f * h, NAME_MARGIN_F * h,
                    names[i], 0.052f * h, "#060B35", density);
            name.setEllipsize(TextUtils.TruncateAt.END);
            cell.addView(name);
            nameViews[i] = name;

            ImageView status = new ImageView(activity);
            int iconSize = px(0.105f * h, density);
            FrameLayout.LayoutParams statusParams = new FrameLayout.LayoutParams(iconSize, iconSize);
            statusParams.gravity = Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL;
            statusParams.bottomMargin = px(STATUS_MARGIN_F * h, density);
            status.setLayoutParams(statusParams);
            status.setImageResource(R.drawable.ic_status_waiting);
            cell.addView(status);
            statusViews[i] = status;

            row.addView(cell);
        }
    }

    private TextView makeLabel(float widthDp, float heightDp, float marginBottomDp,
                              String text, float sizeSp, String colorHex, float density) {
        TextView view = new TextView(activity);
        FrameLayout.LayoutParams params =
                new FrameLayout.LayoutParams(px(widthDp, density), px(heightDp, density));
        params.gravity = Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL;
        params.bottomMargin = px(marginBottomDp, density);
        view.setLayoutParams(params);
        view.setText(text);
        view.setTextColor(Color.parseColor(colorHex));
        view.setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp);
        view.setGravity(Gravity.CENTER);
        view.setMaxLines(1);
        view.setIncludeFontPadding(false);
        if (balooFont != null) {
            view.setTypeface(balooFont, Typeface.BOLD);
        } else {
            view.setTypeface(Typeface.DEFAULT_BOLD);
        }
        return view;
    }

    /**
     * Begins a new round. Everyone shows the waiting clock; the bots privately
     * lock their (predetermined) answer. {@code rightAnswer} is the displayed index 1-4.
     */
    void startRound(String questionLevel, int rightAnswer) {
        if (!active) return;
        for (int i = 0; i < count; i++) {
            roundCorrect[i] = false;
            setStatusIcon(i, R.drawable.ic_status_waiting);
        }
        for (int i = 1; i < count; i++) {
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
        for (int i = 0; i < count; i++) {
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
        return scores == null ? 0 : scores[0];
    }

    int playerRank() {
        int rank = 1;
        for (int i = 1; i < count; i++) {
            if (scores[i] > scores[0]) rank++;
        }
        return rank;
    }

    int playerCount() {
        return count;
    }

    boolean playerIsWinner() {
        for (int i = 1; i < count; i++) {
            if (scores[i] > scores[0]) return false;
        }
        return true; // ties resolve in the player's favour
    }

    String leaderName() {
        int best = 0;
        for (int i = 1; i < count; i++) {
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
        if (statusViews != null && slot < statusViews.length && statusViews[slot] != null) {
            statusViews[slot].setImageResource(resId);
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

    private String pickName(boolean female, Set<String> used) {
        String[] pool = female ? FEMALE_NAMES : MALE_NAMES;
        for (int attempt = 0; attempt < 12; attempt++) {
            String candidate = pool[random.nextInt(pool.length)];
            if (!used.contains(candidate)) {
                return candidate;
            }
        }
        return pool[random.nextInt(pool.length)];
    }

    private int px(float dp, float density) {
        return Math.round(dp * density);
    }
}
