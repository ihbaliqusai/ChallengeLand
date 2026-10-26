package com.qi7bali.landchallengeonline;

import android.content.Context;

final class AppPrefs {
    static boolean musicEnabled = true;
    static boolean soundEnabled = true;
    static boolean isMusicEnabled(Context context) { return musicEnabled; }
    static boolean isSoundEnabled(Context context) { return soundEnabled; }
}
