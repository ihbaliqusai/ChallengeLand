package com.qi7bali.landchallengeonline;

/** Regression checks for scene routing and the measured source-level balance. */
public final class GameAudioProfileCheck {
    private static int checks;
    private static void check(boolean condition, String message) {
        checks++;
        if (!condition) throw new AssertionError(message);
    }

    public static void main(String[] args) {
        for (int question = -1; question <= 50; question++) {
            int music = GameAudioProfile.questionMusic(question);
            check(music != R.raw.s_1000000 && music != R.raw.main_theme_4,
                    "Question background must never be a victory cue");
        }
        check(GameAudioProfile.questionMusic(4) == R.raw.main_theme_0, "Opening questions stay calm");
        check(GameAudioProfile.questionMusic(5) == R.raw.main_theme_1, "Second band begins at question 6");
        check(GameAudioProfile.questionMusic(9) == R.raw.main_theme_1, "Second band ends at question 10");
        check(GameAudioProfile.questionMusic(10) == R.raw.s_64000, "Final band begins at question 11");
        check(GameAudioProfile.boardQuestionMusic(200) == R.raw.main_theme_0, "200-point board music");
        check(GameAudioProfile.boardQuestionMusic(400) == R.raw.main_theme_1, "400-point board music");
        check(GameAudioProfile.boardQuestionMusic(600) == R.raw.s_64000, "600-point board music");
        check(GameAudioProfile.victoryMusic("1000000$") == R.raw.s_1000000, "Jackpot celebration");
        check(GameAudioProfile.victoryMusic("١٬٠٠٠٬٠٠٠$") == R.raw.s_1000000, "Localized jackpot amount");
        check(GameAudioProfile.victoryMusic("999999$") == R.raw.main_theme_4, "Ordinary victory cue");
        check(GameAudioProfile.victoryMusic(null) == R.raw.main_theme_4, "Absent amount fallback");
        check(GameAudioProfile.victoryMusic("unknown") == R.raw.main_theme_4, "Invalid amount fallback");
        check(GameAudioProfile.victoryMusic("-1000000$") == R.raw.main_theme_4, "Negative amount cannot be jackpot");
        check(Math.abs(level(-12.8, GameAudioProfile.musicVolume(R.raw.main_theme_320bit_chosic))
                - level(-23.4, GameAudioProfile.musicVolume(R.raw.main_theme_0))) < 1.0,
                "Retained overture and replacement bed must have comparable playback levels");
        check(Math.abs(level(-19.1, GameAudioProfile.musicVolume(R.raw.sneaky_snitch))
                - level(-23.4, GameAudioProfile.musicVolume(R.raw.main_theme_0))) < 1.0,
                "Campaign music must have a comparable playback level");
        check(Math.abs(level(-16.4, GameAudioProfile.effectVolume(R.raw.drum1)) - (-22.2)) < 3.0,
                "Restored anticipation recording must not dominate answer feedback");
        System.out.println("Game audio profile: " + checks + " checks passed.");
    }

    private static double level(double rmsDb, float gain) {
        return rmsDb + 20.0 * Math.log10(gain);
    }
}
