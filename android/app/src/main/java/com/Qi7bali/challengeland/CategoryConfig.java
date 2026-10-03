package com.qi7bali.landchallengeonline;

import java.util.Arrays;
import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

/**
 * Configuration and categorization of quiz categories in ChallengeLand.
 * - CORE_FREE: Always unlocked for all players (ensures great FTUE and retention).
 * - PREMIUM: High-value, pop-culture, visual or specialty categories that players can unlock
 *   either permanently (gems) or temporarily for 24 hours (rewarded ad).
 */
public final class CategoryConfig {
    private CategoryConfig() {}

    public static final int DEFAULT_PERMANENT_GEM_COST = 150;
    public static final int DEFAULT_AD_RENTAL_HOURS = 24;

    // Normalised list of premium categories
    private static final Set<String> PREMIUM_CATEGORIES = Collections.unmodifiableSet(new HashSet<>(Arrays.asList(
            "أفلام أجنبية",
            "أفلام عربية",
            "أنمي",
            "الأنمي",
            "خمن الأغنية",
            "خمن الأكلة",
            "خمن الاسم",
            "خمن الصورة",
            "خمن المدينة او الدولة",
            "ركز شوي",
            "زووم",
            "سبيس تون",
            "سيارات",
            "فنون وسينما",
            "فيروز",
            "كأس العالم",
            "كأس العالم ",
            "كلثوميات",
            "مسلسل Friends",
            "مسلسلات أجنبية",
            "مسلسلات عربية",
            "وضح شوي"
    )));

    public static boolean isPremium(String rawCategory) {
        if (rawCategory == null) return false;
        String cat = normalize(rawCategory);
        for (String p : PREMIUM_CATEGORIES) {
            if (normalize(p).equals(cat)) {
                return true;
            }
        }
        return false;
    }

    public static boolean isCoreFree(String rawCategory) {
        return !isPremium(rawCategory);
    }

    public static String normalize(String s) {
        if (s == null) return "";
        String normalized = s.trim()
                .replace("أ", "ا")
                .replace("إ", "ا")
                .replace("آ", "ا")
                .replace("ة", "ه")
                .replace("ى", "ي");
        return normalized.equals("الانمي") ? "انمي" : normalized;
    }

    public static Set<String> getPremiumCategories() {
        return PREMIUM_CATEGORIES;
    }
}
