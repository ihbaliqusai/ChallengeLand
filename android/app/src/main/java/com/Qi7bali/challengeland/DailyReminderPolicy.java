package com.qi7bali.landchallengeonline;

import java.util.Calendar;
import java.util.GregorianCalendar;
import java.util.TimeZone;

/** Calendar days preserve local time across daylight saving changes. */
public final class DailyReminderPolicy {
    private DailyReminderPolicy() {}

    public static String dayKey(long now, TimeZone zone) {
        Calendar day = new GregorianCalendar(zone);
        day.setTimeInMillis(now);
        return day.get(Calendar.YEAR) + "-" + day.get(Calendar.MONTH) + "-" + day.get(Calendar.DAY_OF_MONTH);
    }

    public static long nextTriggerAt(long now, TimeZone zone, String lastDeliveredDay) {
        Calendar next = new GregorianCalendar(zone);
        next.setTimeInMillis(now);
        next.set(Calendar.HOUR_OF_DAY, 20);
        next.set(Calendar.MINUTE, 0);
        next.set(Calendar.SECOND, 0);
        next.set(Calendar.MILLISECOND, 0);
        if (next.getTimeInMillis() <= now || dayKey(now, zone).equals(lastDeliveredDay)) {
            next.add(Calendar.DAY_OF_YEAR, 1);
        }
        return next.getTimeInMillis();
    }
}
