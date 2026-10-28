package com.qi7bali.landchallengeonline;

/** Cue routing and gain staging for the actual recordings shipped by the game. */
public final class GameAudioProfile {
    private GameAudioProfile() {}

    public static int questionMusic(int questionIndex) {
        return R.raw.echoes_of_time;
    }

    public static int boardQuestionMusic(int cellValue) {
        return R.raw.echoes_of_time;
    }

    public static int gameplayMusic() {
        return R.raw.echoes_of_time;
    }

    public static int campaignMapMusic() {
        return R.raw.labyrinth_of_lost_dreams;
    }

    public static int victoryMusic(String amount) {
        if (amount == null || amount.trim().startsWith("-")) return R.raw.main_theme_4;
        long prize = 0;
        for (int i = 0; i < amount.length(); i++) {
            int digit = Character.digit(amount.charAt(i), 10);
            if (digit < 0) continue;
            prize = prize * 10 + digit;
            if (prize >= 1_000_000) return R.raw.s_1000000;
        }
        return R.raw.main_theme_4;
    }

    public static float musicVolume(int resource) {
        // The retained overture is about 10 dB louder than the new beds.
        if (resource == R.raw.main_theme_320bit_chosic) return 0.15f;
        if (resource == R.raw.sneaky_snitch) return 0.30f;
        if (resource == R.raw.bgm_lobby) return 0.30f;
        if (resource == R.raw.echoes_of_time) return 0.24f;
        if (resource == R.raw.labyrinth_of_lost_dreams) return 0.23f;
        return 0.50f;
    }

    public static float effectVolume(int resource) {
        // Preserve the requested recording, balancing its louder source level.
        return resource == R.raw.drum1 ? 0.60f : 1.0f;
    }
}
