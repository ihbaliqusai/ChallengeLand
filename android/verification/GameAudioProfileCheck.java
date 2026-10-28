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
        check(GameAudioProfile.questionMusic(4) == R.raw.echoes_of_time, "Opening questions use gameplay bed");
        check(GameAudioProfile.questionMusic(5) == R.raw.echoes_of_time, "Second band uses gameplay bed");
        check(GameAudioProfile.questionMusic(9) == R.raw.echoes_of_time, "Second band uses gameplay bed");
        check(GameAudioProfile.questionMusic(10) == R.raw.echoes_of_time, "Final band uses gameplay bed");
        check(GameAudioProfile.boardQuestionMusic(200) == R.raw.echoes_of_time, "200-point board music uses gameplay bed");
        check(GameAudioProfile.boardQuestionMusic(400) == R.raw.echoes_of_time, "400-point board music uses gameplay bed");
        check(GameAudioProfile.boardQuestionMusic(600) == R.raw.echoes_of_time, "600-point board music uses gameplay bed");
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
        check(Math.abs(level(-16.94, GameAudioProfile.musicVolume(R.raw.echoes_of_time))
                - level(-23.4, GameAudioProfile.musicVolume(R.raw.main_theme_0))) < 1.0,
                "Echoes of time gameplay bed must have a comparable playback level");
        check(Math.abs(level(-16.73, GameAudioProfile.musicVolume(R.raw.labyrinth_of_lost_dreams))
                - level(-23.4, GameAudioProfile.musicVolume(R.raw.main_theme_0))) < 1.0,
                "Labyrinth of lost dreams campaign bed must have a comparable playback level");
        check(Math.abs(level(-19.1, GameAudioProfile.musicVolume(R.raw.bgm_lobby))
                - level(-23.4, GameAudioProfile.musicVolume(R.raw.main_theme_0))) < 1.0,
                "Halloween Horror lobby bed must have a comparable playback level");
        check(Math.abs(level(-16.4, GameAudioProfile.effectVolume(R.raw.drum1)) - (-22.2)) < 3.0,
                "Restored anticipation recording must not dominate answer feedback");
        System.out.println("Game audio profile: " + checks + " checks passed.");
    }

    private static double level(double rmsDb, float gain) {
        return rmsDb + 20.0 * Math.log10(gain);
    }
}
