package com.qi7bali.landchallengeonline;

import android.content.Context;

/**
 * Unlock and purchase rules. Keep indices, prices and level requirements in
 * sync with lib/models/game_character.dart. Existing indices never change.
 */
final class CharacterUnlocks {
    private CharacterUnlocks() {}

    static final int CHARACTER_COUNT = 16;

    static boolean isValid(int index) {
        return index >= 0 && index < CHARACTER_COUNT;
    }

    static String purchaseCurrency(int index) {
        switch (index) {
            case 2: case 9: case 11: case 15: return "coins";
            case 4: case 7: case 12: case 14: return "gems";
            default: return "";
        }
    }

    static int purchaseCost(int index) {
        switch (index) {
            case 2: return 12000;
            case 4: return 300;
            case 7: return 800;
            case 9: return 18000;
            case 11: return 22000;
            case 12: return 450;
            case 14: return 650;
            case 15: return 16000;
            default: return 0;
        }
    }

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
            case 8:
                return AppPrefs.getLevel(c) >= 20;
            case 10:
                return AppPrefs.getLevel(c) >= 12;
            case 13:
                return AppPrefs.getLevel(c) >= 25;
            case 2:
            case 4:
            case 7:
            case 9:
            case 11:
            case 12:
            case 14:
            case 15:
                return AppPrefs.isCharacterPurchased(c, index);
            default:
                return false;
        }
    }
}
