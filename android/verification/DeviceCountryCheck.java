package com.qi7bali.landchallengeonline;

import java.util.Locale;
import java.util.Objects;

/** JVM checks for country validation and ordered fallback without telephony or GPS access. */
public final class DeviceCountryCheck {
    private static int checks;

    public static void main(String[] args) {
        expect("TR", DeviceCountry.chooseCandidate("tr", "jo", "us"));
        expect("JO", DeviceCountry.chooseCandidate(null, "", "zz", "jo", "us"));
        expect("US", DeviceCountry.chooseCandidate("unknown", "UK", "001", "us"));
        expect("AE", DeviceCountry.chooseCandidate("  aE  "));
        expect(null, DeviceCountry.chooseCandidate((String[]) null));
        expect(null, DeviceCountry.chooseCandidate());
        expect(null, DeviceCountry.chooseCandidate(null, "", " ", "ZZ", "UK", "XK", "419"));
        expect(null, DeviceCountry.chooseCandidate("Türkiye", "TUR", "tr-TR", "US/CA"));

        Locale previous = Locale.getDefault();
        try {
            Locale.setDefault(Locale.forLanguageTag("tr-TR"));
            expect("IN", DeviceCountry.chooseCandidate("in"));
        } finally {
            Locale.setDefault(previous);
        }
        for (String country : Locale.getISOCountries()) {
            expect(country, DeviceCountry.chooseCandidate(country.toLowerCase(Locale.ROOT)));
        }
        System.out.println("Device country checks passed: " + checks);
    }

    private static void expect(String expected, String actual) {
        checks++;
        if (!Objects.equals(expected, actual)) {
            throw new AssertionError("Expected " + expected + ", got " + actual);
        }
    }
}
