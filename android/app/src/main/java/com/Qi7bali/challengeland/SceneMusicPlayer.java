package com.qi7bali.landchallengeonline;

import android.content.Context;
import android.content.res.AssetFileDescriptor;
import android.media.MediaPlayer;
import android.util.Log;

/** One scene soundtrack, prepared asynchronously so opening the lobby never
 * waits for MediaPlayer.create()/prepare() on Android's main thread. */
final class SceneMusicPlayer {
    private final Context context;
    private MediaPlayer player;
    private int resource;
    private boolean preparing;
    private boolean foreground;

    SceneMusicPlayer(Context context) { this.context = context.getApplicationContext(); }

    void setForeground(boolean foreground) {
        this.foreground = foreground;
        if (!foreground) release();
    }

    void play(int rawResource, float volume) {
        if (!foreground) return;
        if (player != null && resource == rawResource) {
            if (preparing) return;
            try {
                if (!player.isPlaying()) player.start();
                return;
            } catch (IllegalStateException ignored) { release(); }
        }
        release();
        final MediaPlayer candidate = new MediaPlayer();
        player = candidate;
        resource = rawResource;
        preparing = true;
        try (AssetFileDescriptor source = context.getResources().openRawResourceFd(rawResource)) {
            candidate.setDataSource(source.getFileDescriptor(), source.getStartOffset(), source.getLength());
            candidate.setLooping(true);
            candidate.setVolume(volume, volume);
            candidate.setOnPreparedListener(ready -> {
                if (player != ready || !foreground) return;
                preparing = false;
                try { ready.start(); }
                catch (IllegalStateException ignored) { release(); }
            });
            candidate.setOnErrorListener((failed, what, extra) -> {
                if (player == failed) release();
                return true;
            });
            candidate.prepareAsync();
        } catch (Exception error) {
            Log.w("SceneMusic", "Unable to prepare scene soundtrack", error);
            if (player == candidate) release();
        }
    }

    void stopIf(int rawResource) { if (resource == rawResource) release(); }

    void release() {
        MediaPlayer previous = player;
        player = null;
        resource = 0;
        preparing = false;
        if (previous == null) return;
        previous.setOnPreparedListener(null);
        previous.setOnErrorListener(null);
        previous.release();
    }
}
