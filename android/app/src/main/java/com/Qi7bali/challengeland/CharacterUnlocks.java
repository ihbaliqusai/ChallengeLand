package com.qi7bali.landchallengeonline;

import android.content.Context;

/**
 * Unlock rules for the eight playable characters. MUST stay in sync with the
 * Flutter catalog in lib/models/game_character.dart:
 *   free    : 1 (Omar), 6 (Sarah)
 *   level   : 0 (Khaled)=4, 3 (Mazen)=8, 5 (Ellen)=15
 *   purchase: 2 (Fahad), 4 (Mahmoud), 7 (Talia)
 */
final class CharacterUnlocks {
    private CharacterUnlocks() {}

    static boolean isUnlocked(Context c, int index) {
        switch (index) {
            case 1:
            case 6:
                return true; // free
            case 0:
                return AppPrefs.getLevel(c) >= 4;
            case 3:
                return AppPrefs.getLevel(c) >= 8;
            case 5:
                return AppPrefs.getLevel(c) >= 15;
            case 2:
            case 4:
            case 7:
                return AppPrefs.isCharacterPurchased(c, index);
            default:
                return false;
        }
    }
}
