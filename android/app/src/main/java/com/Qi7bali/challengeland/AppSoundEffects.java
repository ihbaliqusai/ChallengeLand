package com.qi7bali.landchallengeonline;

import android.content.Context;
import android.media.AudioAttributes;
import android.media.AudioManager;
import android.media.SoundPool;
import android.util.Log;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

/**
 * Lightweight, zero-latency SoundPool manager for instant UI effects (clicks, wheel ticks, win chimes).
 * Uses uncompressed 16-bit PCM WAV assets for guaranteed instant playback on all Android versions.
 * Respects AppPrefs.isSoundEnabled().
 */
public final class AppSoundEffects {
    private static final String TAG = "AppSoundEffects";

    public static final String EFFECT_CLICK = "click";
    public static final String EFFECT_WHEEL_TICK = "wheel_tick";
    public static final String EFFECT_WHEEL_WIN = "wheel_win";

    private static SoundPool soundPool;
    private static final Map<String, Integer> soundIds = new HashMap<>();
    private static final Map<String, Float> soundVolumes = new HashMap<>();
    private static final Set<Integer> readySoundIds = Collections.synchronizedSet(new HashSet<>());
    private static boolean initialized = false;

    private AppSoundEffects() {}

    public static synchronized void init(Context context) {
        if (initialized && soundPool != null) return;
        if (context == null) return;

        Context appCtx = context.getApplicationContext();
        try {
            AudioAttributes attributes = new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build();

            soundPool = new SoundPool.Builder()
                    .setMaxStreams(12)
                    .setAudioAttributes(attributes)
                    .build();

            soundPool.setOnLoadCompleteListener((pool, sampleId, status) -> {
                if (status == 0) {
                    readySoundIds.add(sampleId);
                    Log.d(TAG, "Sound sample ready: id=" + sampleId);
                } else {
                    Log.w(TAG, "Sound sample failed to load: id=" + sampleId + ", status=" + status);
                }
            });

            load(appCtx, EFFECT_CLICK, R.raw.sfx_button_click, 1.0f);
            load(appCtx, EFFECT_WHEEL_TICK, R.raw.sfx_wheel_tick, 0.85f);
            load(appCtx, EFFECT_WHEEL_WIN, R.raw.sfx_wheel_win, 1.0f);
            initialized = true;
            Log.d(TAG, "AppSoundEffects initialized with SoundPool");
        } catch (Exception e) {
            Log.w(TAG, "Failed to initialize SoundPool", e);
        }
    }

    private static void load(Context context, String effect, int resId, float defaultVolume) {
        if (soundPool == null) return;
        try {
            int id = soundPool.load(context, resId, 1);
            soundIds.put(effect, id);
            soundVolumes.put(effect, defaultVolume);
            Log.d(TAG, "Registered " + effect + " with soundId=" + id + " from res=" + resId);
        } catch (Exception e) {
            Log.w(TAG, "Failed to load effect " + effect, e);
        }
    }

    private static volatile long lastClickTimeMs = 0L;
    private static final long CLICK_DEBOUNCE_MS = 90L;

    public static boolean play(Context context, String effect) {
        if (context == null) return false;
        if (!AppPrefs.isSoundEnabled(context)) return false;

        if (EFFECT_CLICK.equals(effect)) {
            long now = android.os.SystemClock.elapsedRealtime();
            if (now - lastClickTimeMs < CLICK_DEBOUNCE_MS) {
                return true;
            }
            lastClickTimeMs = now;
        }

        if (!initialized || soundPool == null) {
            init(context);
        }

        Integer id = soundIds.get(effect);
        Float volume = soundVolumes.get(effect);
        float vol = volume != null ? volume : 1.0f;

        if (id != null && id > 0 && soundPool != null && readySoundIds.contains(id)) {
            try {
                int streamId = soundPool.play(id, vol, vol, 1, 0, 1.0f);
                if (streamId > 0) {
                    return true;
                }
                Log.w(TAG, "SoundPool.play returned 0 for " + effect + " (id=" + id + ")");
            } catch (Exception e) {
                Log.w(TAG, "Exception playing sound " + effect, e);
            }
        }

        // Fallback for click if SoundPool is still preparing
        if (EFFECT_CLICK.equals(effect)) {
            try {
                AudioManager am = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
                if (am != null) {
                    am.playSoundEffect(AudioManager.FX_KEY_CLICK);
                    return true;
                }
            } catch (Exception ignored) {}
        }

        return false;
    }

    public static boolean click(Context context) {
        return play(context, EFFECT_CLICK);
    }

    public static boolean wheelTick(Context context) {
        return play(context, EFFECT_WHEEL_TICK);
    }

    public static boolean wheelWin(Context context) {
        return play(context, EFFECT_WHEEL_WIN);
    }

    public static synchronized void release() {
        if (soundPool != null) {
            try {
                soundPool.release();
            } catch (Exception ignored) {}
            soundPool = null;
        }
        soundIds.clear();
        soundVolumes.clear();
        readySoundIds.clear();
        initialized = false;
    }
}
