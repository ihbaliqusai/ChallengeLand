package com.qi7bali.landchallengeonline;

import org.json.JSONArray;
import org.json.JSONObject;
import java.nio.file.Files;
import java.nio.file.Paths;

/** Checks persistence, account isolation and unlock rules for the imported pack. */
public final class CharacterUnlocksCheck {
    private static int assertions;
    private static void check(boolean value, String message) {
        assertions++;
        if (!value) throw new AssertionError(message);
    }

    public static void main(String[] args) throws Exception {
        JSONArray pack = new JSONArray(Files.readString(Paths.get(args[0])));
        VerificationContext device = new VerificationContext();
        device.switchAccount("character-owner");
        check(CharacterUnlocks.CHARACTER_COUNT == 16, "complete roster size");
        for (int index = 0; index < CharacterUnlocks.CHARACTER_COUNT; index++) {
            check(CharacterUnlocks.isValid(index), "valid roster index " + index);
            AppPrefs.setSelectedCharacter(device, index);
            check(AppPrefs.getSelectedCharacter(device) == index, "saved roster index " + index);
            check(AppPrefs.getEffectiveCharacter(device) == index, "in-game roster index " + index);
        }
        for (int index : new int[]{-2, 16, 1000}) {
            check(!CharacterUnlocks.isValid(index), "reject invalid index " + index);
            AppPrefs.setSelectedCharacter(device, index);
            check(AppPrefs.getSelectedCharacter(device) == 15, "invalid index cannot replace selection");
        }
        check(CharacterUnlocks.isUnlocked(device, 1), "Omar remains free");
        check(CharacterUnlocks.isUnlocked(device, 6), "Sarah remains free");
        check(CharacterUnlocks.purchaseCost(2) == 12000, "Fahad price preserved");
        check(CharacterUnlocks.purchaseCost(4) == 300, "Mahmoud price preserved");
        check(CharacterUnlocks.purchaseCost(7) == 800, "Talia price preserved");
        for (int row = 0; row < pack.length(); row++) {
            JSONObject character = pack.getJSONObject(row);
            int index = character.getInt("index"), amount = character.getInt("value");
            String kind = character.getString("kind");
            PlayerProgress.setXp(device, 0);
            check(!CharacterUnlocks.isUnlocked(device, index), "new character initially locked " + index);
            if (kind.equals("level")) {
                check(CharacterUnlocks.purchaseCost(index) == 0, "level character cannot be bought");
                PlayerProgress.setXp(device, xpForLevel(amount) - 1);
                check(!CharacterUnlocks.isUnlocked(device, index), "locked one XP before unlock " + index);
                PlayerProgress.addXp(device, 1);
                check(CharacterUnlocks.isUnlocked(device, index), "unlock at required level " + index);
            } else {
                check(CharacterUnlocks.purchaseCurrency(index).equals(kind), "purchase currency " + index);
                check(CharacterUnlocks.purchaseCost(index) == amount, "purchase amount " + index);
                PlayerProgress.setXp(device, xpForLevel(100));
                check(!CharacterUnlocks.isUnlocked(device, index), "level does not bypass purchase " + index);
                AppPrefs.unlockCharacter(device, index);
                check(CharacterUnlocks.isUnlocked(device, index), "purchased character available " + index);
            }
        }
        AppPrefs.setSelectedCharacter(device, 15);
        device.switchAccount("other-character-owner");
        check(AppPrefs.getSelectedCharacter(device) == -1, "selection isolated across accounts");
        check(!CharacterUnlocks.isUnlocked(device, 15), "purchase isolated across accounts");
        device.switchAccount("character-owner");
        check(AppPrefs.getSelectedCharacter(device) == 15, "new selection survives account switch");
        check(CharacterUnlocks.isUnlocked(device, 15), "new purchase survives account switch");
        AppPrefs.setSelectedCharacter(device, -1);
        check(AppPrefs.getSelectedCharacter(device) == -1, "hydration can clear a stale selection");
        check(AppPrefs.getEffectiveCharacter(device) == AppPrefs.DEFAULT_CHARACTER, "unset selection renders the default");
        VerificationContext legacy = new VerificationContext();
        legacy.namespace(AppPrefs.PREF_USER).values.put("userID", "legacy-owner");
        legacy.namespace(AppPrefs.PREF_USER).values.put("selectedCharacter", 7);
        legacy.namespace(AppPrefs.PREF_USER).values.put("unlockedCharacters", new java.util.HashSet<>(java.util.Arrays.asList("7", "4")));
        legacy.switchAccount("different-owner");
        check(AppPrefs.getSelectedCharacter(legacy) == -1, "old selection does not migrate to another account");
        check(AppPrefs.getUnlockedCharacters(legacy).isEmpty(), "old purchases do not migrate to another account");
        legacy.switchAccount("legacy-owner");
        check(AppPrefs.getSelectedCharacter(legacy) == 7, "upgrade preserves old selected character");
        check(AppPrefs.isCharacterPurchased(legacy, 7) && AppPrefs.isCharacterPurchased(legacy, 4), "upgrade preserves old purchases");
        System.out.println("Character roster checks passed (" + assertions + " assertions)");
    }

    private static int xpForLevel(int level) {
        int xp = 0;
        for (int n = 1; n < level; n++) {
            if (n < 5) xp += 120 + (n - 1) * 40;
            else if (n < 10) xp += 320 + (n - 5) * 55;
            else if (n < 20) xp += 620 + (n - 10) * 80;
            else if (n < 30) xp += 1450 + (n - 20) * 130;
            else if (n < 45) xp += 2850 + (n - 30) * 210;
            else if (n < 60) xp += 6000 + (n - 45) * 360;
            else xp += 11500 + (n - 60) * 550;
        }
        return xp;
    }
}
