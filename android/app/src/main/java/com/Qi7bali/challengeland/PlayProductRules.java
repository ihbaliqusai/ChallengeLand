package com.qi7bali.landchallengeonline;

/** Settlement policy for a product ID already accepted by the native catalog. */
public final class PlayProductRules {
    private PlayProductRules() {}

    public static boolean isConsumable(String canonicalId) {
        if (canonicalId == null) return false;
        return canonicalId.startsWith("gems_") || canonicalId.startsWith("coins_")
                || canonicalId.startsWith("keys_") || canonicalId.startsWith("hearts_")
                || canonicalId.startsWith("tickets_") || canonicalId.startsWith("resources_")
                || canonicalId.equals("pack_value") || canonicalId.equals("pack_champion");
    }
}
