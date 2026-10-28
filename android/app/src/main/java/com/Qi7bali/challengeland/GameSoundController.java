package com.qi7bali.landchallengeonline;

import android.content.Context;
import android.media.MediaPlayer;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;

import java.util.ArrayList;
import java.util.IdentityHashMap;

final class GameSoundController {
    private static final long FADE_DURATION_MS = 350;
    private static final long FADE_FRAME_MS = 25;

    private final Context context;
    private final Handler fadeHandler = new Handler(Looper.getMainLooper());
    private final IdentityHashMap<MediaPlayer, Playback> activePlayers = new IdentityHashMap<>();
    private MediaPlayer currentMusicPlayer;
    private MediaPlayer currentEffectPlayer;
    private float effectVolumeScale = 1f;

    private static final class Playback {
        final MediaPlayer player;
        final int resourceId;
        final boolean music;
        final boolean looping;
        final float baseVolume;
        float fadeFactor = 1f;
        Runnable fade;

        Playback(MediaPlayer player, int resourceId, boolean music, boolean looping, float baseVolume) {
            this.player = player;
            this.resourceId = resourceId;
            this.music = music;
            this.looping = looping;
            this.baseVolume = baseVolume;
        }
    }

    GameSoundController(Context context) {
        this.context = context.getApplicationContext();
    }

    void play(int resId, boolean fading, boolean looping, boolean exiting) {
        if (exiting) return;

        boolean targetIsMusic = isMusicTrack(resId);
        if (targetIsMusic) {
            if (!AppPrefs.isMusicEnabled(context)) {
                stopChannel(true);
                return;
            }
        } else if (!AppPrefs.isSoundEnabled(context)) {
            return;
        }

        MediaPlayer current = targetIsMusic ? currentMusicPlayer : currentEffectPlayer;
        Playback existing = activePlayers.get(current);
        if (targetIsMusic && looping && existing != null && existing.looping
                && existing.resourceId == resId && existing.fade == null) {
            return;
        }

        // Only the outgoing/current pair may overlap; repeated triggers must
        // not accumulate a collection of fading players.
        for (Playback playback : new ArrayList<>(activePlayers.values())) {
            if (playback.music == targetIsMusic && playback.player != current) stop(playback);
        }
        if (existing != null) {
            if (fading) fade(existing);
            else stop(existing);
        }
        createPlayer(resId, looping, targetIsMusic);
    }

    void setCurrentEffectVolume(float volume) {
        effectVolumeScale = clamp(volume);
        for (Playback playback : new ArrayList<>(activePlayers.values())) {
            if (playback.music) continue;
            if (effectVolumeScale == 0f && playback.fade != null) stop(playback);
            else applyVolume(playback);
        }
    }

    void stopCurrentMusicIfDisabled(boolean musicEnabled) {
        if (!musicEnabled) stopChannel(true);
    }

    void stopCurrentEffect() {
        stopChannel(false);
    }

    void stopCurrent() {
        for (Playback playback : new ArrayList<>(activePlayers.values())) stop(playback);
        currentMusicPlayer = null;
        currentEffectPlayer = null;
        fadeHandler.removeCallbacksAndMessages(null);
    }

    void releaseCurrent() {
        stopCurrent();
    }

    private void createPlayer(int resId, boolean looping, boolean music) {
        MediaPlayer player = null;
        Playback playback = null;
        try {
            player = MediaPlayer.create(context, resId);
            if (player == null) return;
            float gain = music ? GameAudioProfile.musicVolume(resId) : GameAudioProfile.effectVolume(resId);
            playback = new Playback(player, resId, music, looping, clamp(gain));
            final Playback created = playback;
            activePlayers.put(player, playback);
            if (music) currentMusicPlayer = player;
            else currentEffectPlayer = player;
            player.setLooping(looping);
            player.setOnCompletionListener(completed -> stop(created));
            player.setOnErrorListener((failed, what, extra) -> {
                stop(created);
                return true;
            });
            if (!applyVolume(playback)) return;
            player.start();
        } catch (RuntimeException ignored) {
            if (playback != null) stop(playback);
            else release(player);
        }
    }

    private boolean applyVolume(Playback playback) {
        if (activePlayers.get(playback.player) != playback) return false;
        float gain = playback.baseVolume * playback.fadeFactor
                * (playback.music ? 1f : effectVolumeScale);
        try {
            playback.player.setVolume(gain, gain);
            return true;
        } catch (RuntimeException ignored) {
            stop(playback);
            return false;
        }
    }

    private void stopChannel(boolean music) {
        for (Playback playback : new ArrayList<>(activePlayers.values())) {
            if (playback.music == music) stop(playback);
        }
    }

    private void stop(Playback playback) {
        if (activePlayers.get(playback.player) != playback) return;
        activePlayers.remove(playback.player);
        if (playback.fade != null) {
            fadeHandler.removeCallbacks(playback.fade);
            playback.fade = null;
        }
        if (currentMusicPlayer == playback.player) currentMusicPlayer = null;
        if (currentEffectPlayer == playback.player) currentEffectPlayer = null;
        release(playback.player);
    }

    static void release(MediaPlayer player) {
        if (player == null) return;
        try {
            if (player.isPlaying()) {
                player.stop();
            }
        } catch (Exception ignored) {
        }
        try {
            player.release();
        } catch (Exception ignored) {
        }
    }

    private boolean isMusicTrack(int resId) {
        return resId == R.raw.main_theme_0
                || resId == R.raw.main_theme_1
                || resId == R.raw.main_theme_2
                || resId == R.raw.main_theme_3
                || resId == R.raw.main_theme_4
                || resId == R.raw.main_theme_5
                || resId == R.raw.main_theme_320bit_chosic
                || resId == R.raw.sneaky_snitch
                || resId == R.raw.bgm_lobby
                || resId == R.raw.echoes_of_time
                || resId == R.raw.labyrinth_of_lost_dreams
                || resId == R.raw.lets_play
                || resId == R.raw.commerical_break
                || resId == R.raw.s_32000
                || resId == R.raw.s_64000
                || resId == R.raw.s_250000
                || resId == R.raw.s_5000000
                || resId == R.raw.s_1000000;
    }

    private void fade(final Playback playback) {
        final long startedAt = SystemClock.uptimeMillis();
        final float startFactor = playback.fadeFactor;
        if (currentMusicPlayer == playback.player) currentMusicPlayer = null;
        if (currentEffectPlayer == playback.player) currentEffectPlayer = null;
        playback.fade = new Runnable() {
            @Override
            public void run() {
                if (activePlayers.get(playback.player) != playback || playback.fade != this) return;
                float progress = Math.min(1f, (SystemClock.uptimeMillis() - startedAt) / (float) FADE_DURATION_MS);
                playback.fadeFactor = startFactor * (1f - progress);
                if (progress >= 1f) {
                    stop(playback);
                } else if (applyVolume(playback)) {
                    fadeHandler.postDelayed(this, FADE_FRAME_MS);
                }
            }
        };
        fadeHandler.postDelayed(playback.fade, FADE_FRAME_MS);
    }

    private static float clamp(float value) {
        return Float.isNaN(value) ? 0f : Math.max(0f, Math.min(1f, value));
    }
}
