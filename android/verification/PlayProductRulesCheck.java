package com.qi7bali.landchallengeonline;

/** Purchased resource packs must be consumed after delivery so they can be bought again. */
public final class PlayProductRulesCheck {
    public static void main(String[] args) {
        for (String id : new String[] {
                "keys_1", "keys_10", "hearts_1", "hearts_10", "tickets_1", "tickets_10",
                "resources_3_each", "resources_10_each", "gems_80", "gems_14000",
                "coins_5000", "coins_100000", "pack_value", "pack_champion", "wheel_spins_3" }) {
            if (!PlayProductRules.isConsumable(id)) throw new AssertionError("Must consume: " + id);
        }
        for (String id : new String[] { null, "pack_starter", "category_all_access", "noads", "vip_monthly" }) {
            if (PlayProductRules.isConsumable(id)) throw new AssertionError("Must retain ownership: " + id);
        }
        System.out.println("Play product settlement checks passed (20 products)");
    }
}
