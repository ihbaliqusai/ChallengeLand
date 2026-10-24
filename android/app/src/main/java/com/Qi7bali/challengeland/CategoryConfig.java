package com.qi7bali.landchallengeonline;

import java.util.Arrays;
import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

/**
 * Configuration and categorization of quiz categories in ChallengeLand.
 * - CORE_FREE: Always unlocked for all players (ensures great FTUE and retention).
 * - PREMIUM: Every other category supports ownership, timed rental or a match ticket.
 *   Only ad-eligible subjects may receive a category-bound single-match ad permit.
 */
public final class CategoryConfig {
    private CategoryConfig() {}

    public static final int DEFAULT_PERMANENT_GEM_COST = 150;
    public static final int DEFAULT_AD_RENTAL_HOURS = 24;
    private static final Set<String> FREE_CATEGORIES = new HashSet<>(Arrays.asList(
            "جغرافيا", "حيوانات", "دين واسلاميات", "عواصم", "دول", "اختراعات", "عملات", "لغة وادب"));
    private static final Set<String> NO_AD_CATEGORIES = new HashSet<>(Arrays.asList(
            "أنمي", "مسلسل Friends", "مسلسلات أجنبية", "مسلسلات عربية", "أفلام أجنبية", "أفلام عربية", "سبيس تون"));

    public static boolean allowsAd(String category) {
        if (isCoreFree(category)) return false;
        for (String value : NO_AD_CATEGORIES) if (normalize(value).equals(normalize(category))) return false;
        return true;
    }

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
            , "معلومات عامة", "تاريخ", "رياضة", "علوم وفضاء", "ألغاز", "أمثال",
            "تقنية", "جسم الإنسان", "نباتات", "لغات", "صحة", "طعام وشراب", "سياحة وسفر",
            "سيرة ذاتية", "قصص الأنبياء", "منوعات"
    )));

    public static boolean isPremium(String rawCategory) {
        if (rawCategory == null) return false;
        String cat = normalize(rawCategory);
        for (String p : FREE_CATEGORIES) {
            if (normalize(p).equals(cat)) {
                return false;
            }
        }
        return !cat.isEmpty();
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
        normalized = normalized.replaceAll("\\s+", " ").toLowerCase(java.util.Locale.ROOT);
        return normalized.equals("الانمي") || normalized.equals("الانيمي") || normalized.equals("انيمي") ? "انمي" : normalized;
    }

    public static Set<String> getPremiumCategories() {
        return PREMIUM_CATEGORIES;
    }
}
