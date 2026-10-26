package com.qi7bali.landchallengeonline;

import android.content.Context;
import android.content.res.Configuration;
import android.content.res.Resources;
import android.os.Build;
import android.os.LocaleList;
import android.telephony.TelephonyManager;

import java.util.Arrays;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;

/** Reads a coarse country hint without location, phone-state permissions or network requests. */
public final class DeviceCountry {
    private static final Set<String> ISO_COUNTRIES =
            new HashSet<>(Arrays.asList(Locale.getISOCountries()));

    private DeviceCountry() {}

    /** Returns a validated uppercase ISO country code, or null when every source is unavailable. */
    public static String getCountryCode(Context context) {
        TelephonyManager telephony = null;
        try {
            if (context != null) {
                Object service = context.getSystemService(Context.TELEPHONY_SERVICE);
                if (service instanceof TelephonyManager) {
                    telephony = (TelephonyManager) service;
                }
            }
        } catch (RuntimeException unavailable) {
            // Devices without a telephony service can still use their configured region.
        }

        if (telephony != null) {
            try {
                String country = chooseCandidate(telephony.getNetworkCountryIso());
                if (country != null) return country;
            } catch (RuntimeException unavailable) {
                // Includes SecurityException and UnsupportedOperationException on OEM devices.
            }
            try {
                String country = chooseCandidate(telephony.getSimCountryIso());
                if (country != null) return country;
            } catch (RuntimeException unavailable) {
                // A failed network-country read must not prevent the independent SIM fallback.
            }
        }

        try {
            // Read the device configuration rather than an app-specific language override.
            Configuration configuration = Resources.getSystem().getConfiguration();
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                LocaleList locales = configuration.getLocales();
                for (int index = 0; index < locales.size(); index++) {
                    String country = chooseCandidate(locales.get(index).getCountry());
                    if (country != null) return country;
                }
            } else {
                @SuppressWarnings("deprecation")
                Locale locale = configuration.locale;
                String country = chooseCandidate(locale == null ? null : locale.getCountry());
                if (country != null) return country;
            }
        } catch (RuntimeException unavailable) {
            // Continue to the process locale if system configuration cannot be read.
        }

        return chooseCandidate(Locale.getDefault().getCountry());
    }

    /** Pure selection logic shared with native verification checks. */
    static String chooseCandidate(String... candidates) {
        if (candidates == null) return null;
        for (String candidate : candidates) {
            if (candidate == null) continue;
            String normalized = candidate.trim().toUpperCase(Locale.ROOT);
            if (ISO_COUNTRIES.contains(normalized)) return normalized;
        }
        return null;
    }
}
