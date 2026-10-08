package com.qi7bali.landchallengeonline;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.TimeZone;

public final class DailyReminderPolicyTest {
    private static int checks;
    private static void check(boolean condition, String message) {
        checks++;
        if (!condition) throw new AssertionError(message);
    }
    private static void expect(String now, String zone, String expected) {
        long result = DailyReminderPolicy.nextTriggerAt(Instant.parse(now).toEpochMilli(), TimeZone.getTimeZone(zone), "");
        check(result == Instant.parse(expected).toEpochMilli(), zone + " next reminder: " + Instant.ofEpochMilli(result));
    }
    public static void main(String[] args) {
        expect("2026-10-08T12:00:00Z", "Europe/Istanbul", "2026-10-08T17:00:00Z");
        expect("2026-10-08T17:00:00Z", "Europe/Istanbul", "2026-10-09T17:00:00Z");
        expect("2026-12-31T22:00:00Z", "UTC", "2027-01-01T20:00:00Z");
        expect("2026-02-28T22:00:00Z", "UTC", "2026-03-01T20:00:00Z");
        expect("2028-02-28T22:00:00Z", "UTC", "2028-02-29T20:00:00Z");
        expect("2026-03-07T23:00:00Z", "America/New_York", "2026-03-08T01:00:00Z");
        expect("2026-03-08T02:00:00Z", "America/New_York", "2026-03-09T00:00:00Z");
        expect("2026-11-01T01:00:00Z", "America/New_York", "2026-11-02T01:00:00Z");

        long now = Instant.parse("2026-10-08T12:00:00Z").toEpochMilli();
        TimeZone zone = TimeZone.getTimeZone("Europe/Istanbul");
        String delivered = DailyReminderPolicy.dayKey(now, zone);
        check(DailyReminderPolicy.nextTriggerAt(now, zone, delivered)
                == Instant.parse("2026-10-09T17:00:00Z").toEpochMilli(), "No second reminder on a delivered day after clock changes");
        check(!DailyReminderPolicy.dayKey(now, TimeZone.getTimeZone("Pacific/Auckland"))
                .equals(delivered), "Day keys follow the phone's timezone");

        for (String name : new String[]{"Europe/Istanbul", "America/New_York", "Europe/Berlin", "Pacific/Auckland"}) {
            ZoneId id = ZoneId.of(name);
            for (int day = 0; day < 365; day++) {
                LocalDate date = LocalDate.of(2026, 1, 1).plusDays(day);
                long afterEvening = date.atTime(21, 0).atZone(id).toInstant().toEpochMilli();
                long next = DailyReminderPolicy.nextTriggerAt(afterEvening, TimeZone.getTimeZone(name), "");
                ZonedDateTime localNext = Instant.ofEpochMilli(next).atZone(id);
                check(localNext.toLocalDate().equals(date.plusDays(1)) && localNext.getHour() == 20
                        && localNext.getMinute() == 0, "Tomorrow at 20:00 including DST: " + localNext);
            }
        }
        System.out.println("Daily reminder policy passed: " + checks + " checks");
    }
}
