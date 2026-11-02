package com.qi7bali.landchallengeonline;

import android.app.Activity;
import android.content.Intent;
import android.test.InstrumentationTestCase;

import com.google.android.gms.tasks.Tasks;
import com.google.firebase.remoteconfig.FirebaseRemoteConfig;
import com.google.firebase.remoteconfig.FirebaseRemoteConfigSettings;

import java.lang.reflect.Field;
import java.util.concurrent.TimeUnit;

/** Deployment check for the initially disabled policy; no match/account writes. */
@SuppressWarnings("deprecation")
public final class AppUpdateControllerTest extends InstrumentationTestCase {
    private Activity activity;

    public void testPublishedInitialPolicyIsRemoteDisabledAndAllowsThisBuild() throws Exception {
        FirebaseRemoteConfig config = FirebaseRemoteConfig.getInstance();
        Tasks.await(config.setConfigSettingsAsync(new FirebaseRemoteConfigSettings.Builder()
                .setFetchTimeoutInSeconds(10).build()), 15, TimeUnit.SECONDS);
        Tasks.await(config.fetch(0), 20, TimeUnit.SECONDS);
        Tasks.await(config.activate(), 10, TimeUnit.SECONDS);
        assertEquals(FirebaseRemoteConfig.VALUE_SOURCE_REMOTE,
                config.getValue("force_update_enabled").getSource());
        assertEquals(FirebaseRemoteConfig.VALUE_SOURCE_REMOTE,
                config.getValue("min_android_build").getSource());
        assertFalse("First publication must not block any player", config.getBoolean("force_update_enabled"));
        assertEquals(49L, config.getLong("min_android_build"));
        assertTrue(config.getString("force_update_message_ar").contains("تحديث"));

        activity = getInstrumentation().startActivitySync(new Intent()
                .setClassName(getInstrumentation().getTargetContext().getPackageName(),
                        "com.qi7bali.landchallengeonline.MainActivity")
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
        Field field = activity.getClass().getDeclaredField("appUpdateController");
        field.setAccessible(true);
        AppUpdateController controller = (AppUpdateController) field.get(activity);
        assertNotNull(controller);
        assertFalse("Native launch guard must allow the published disabled policy", controller.requiresUpdate());
    }

    @Override protected void tearDown() throws Exception {
        try {
            if (activity != null) getInstrumentation().runOnMainSync(() -> activity.finish());
        } finally { super.tearDown(); }
    }
}
