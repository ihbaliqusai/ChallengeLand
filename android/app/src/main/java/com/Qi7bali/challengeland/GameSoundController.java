package net.androidgaming.millionaire2024;

import android.content.Context;
import android.media.MediaPlayer;
import android.os.Handler;

final class GameSoundController {
    private static final float MUSIC_VOLUME = 0.5f;

    private final Context context;
    private MediaPlayer currentMusicPlayer;
    private MediaPlayer currentEffectPlayer;

    GameSoundController(Context context) {
        this.context = context.getApplicationContext();
    }

    void play(int resId, boolean fading, boolean looping, boolean exiting) {
        if (exiting) return;

        boolean targetIsMusic = isMusicTrack(resId, looping);
        if (targetIsMusic) {
            if (!AppPrefs.isMusicEnabled(context)) {
                stopCurrent();
                return;
            }
        } else if (!AppPrefs.isSoundEnabled(context)) {
            return;
        }

        if (targetIsMusic) {
            if (fading) {
                fadeMusic();
            } else {
                stopMusic();
            }
            currentMusicPlayer = createPlayer(resId, looping, true);
        } else {
            if (fading) {
                fadeEffect();
            } else {
                stopEffect();
            }
            currentEffectPlayer = createPlayer(resId, looping, false);
        }
    }

    void setCurrentEffectVolume(float volume) {
        if (currentEffectPlayer != null) {
            currentEffectPlayer.setVolume(volume, volume);
        }
    }

    void stopCurrentMusicIfDisabled(boolean musicEnabled) {
        if (currentMusicPlayer != null && !musicEnabled) {
            stopMusic();
        }
    }

    void stopCurrent() {
        stopMusic();
        stopEffect();
    }

    void releaseCurrent() {
        stopCurrent();
    }

    private MediaPlayer createPlayer(int resId, boolean looping, final boolean music) {
        final MediaPlayer player = MediaPlayer.create(context, resId);
        if (player == null) return null;
        player.setLooping(looping);
        if (music) {
            player.setVolume(MUSIC_VOLUME, MUSIC_VOLUME);
        }
        player.setOnCompletionListener(completed -> {
            if (music && currentMusicPlayer == completed) {
                currentMusicPlayer = null;
            } else if (!music && currentEffectPlayer == completed) {
                currentEffectPlayer = null;
            }
            release(completed);
        });
        player.start();
        return player;
    }

    private void stopMusic() {
        MediaPlayer player = currentMusicPlayer;
        currentMusicPlayer = null;
        release(player);
    }

    private void stopEffect() {
        MediaPlayer player = currentEffectPlayer;
        currentEffectPlayer = null;
        release(player);
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

    private boolean isMusicTrack(int resId, boolean looping) {
        return resId == R.raw.main_theme_0
                || resId == R.raw.main_theme_1
                || resId == R.raw.main_theme_2
                || resId == R.raw.main_theme_3
                || resId == R.raw.main_theme_4
                || resId == R.raw.main_theme_5
                || resId == R.raw.main_theme_320bit_chosic
                || resId == R.raw.commerical_break
                || resId == R.raw.s_32000
                || resId == R.raw.s_64000
                || resId == R.raw.s_250000
                || resId == R.raw.s_5000000
                || resId == R.raw.s_1000000;
    }

    private void fadeMusic() {
        final MediaPlayer player = currentMusicPlayer;
        currentMusicPlayer = null;
        fadePlayer(player);
    }

    private void fadeEffect() {
        final MediaPlayer player = currentEffectPlayer;
        currentEffectPlayer = null;
        fadePlayer(player);
    }

    private void fadePlayer(final MediaPlayer player) {
        if (player == null) return;

        final Handler handler = new Handler();
        handler.postDelayed(new Runnable() {
            int currentVolumeStep = 10;

            @Override
            public void run() {
                try {
                    currentVolumeStep--;
                    float currentVolume = (float) (1 - (Math.log(10 - currentVolumeStep) / Math.log(10)));
                    player.setVolume(currentVolume, currentVolume);
                    if (currentVolumeStep > 0) {
                        handler.postDelayed(this, 100);
                    } else {
                        release(player);
                    }
                } catch (Exception ignored) {
                    release(player);
                }
            }
        }, 100);
    }
}
