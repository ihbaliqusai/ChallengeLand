package com.qi7bali.landchallengeonline;

import android.app.Activity;
import android.media.MediaPlayer;
import android.net.Uri;
import android.widget.VideoView;

final class GameBackgroundVideoController {
    private final Activity activity;
    private final int videoViewId;
    private final int rawVideoResId;
    private VideoView videoView;
    private boolean paused;

    GameBackgroundVideoController(Activity activity, int videoViewId, int rawVideoResId) {
        this.activity = activity;
        this.videoViewId = videoViewId;
        this.rawVideoResId = rawVideoResId;
    }

    void setup() {
        videoView = activity.findViewById(videoViewId);
        if (videoView == null) return;

        Uri videoUri = Uri.parse("android.resource://" + activity.getPackageName() + "/" + rawVideoResId);
        videoView.setVideoURI(videoUri);
        final VideoView preparingView = videoView;
        videoView.setOnPreparedListener(player -> {
            if (videoView != preparingView) return;
            player.setLooping(true);
            player.setVolume(0f, 0f);
            scaleToCenterCrop(player);
            if (paused) preparingView.pause();
            else preparingView.start();
        });
        videoView.setOnErrorListener((player, what, extra) -> true);
    }

    void start() {
        paused = false;
        if (videoView == null) return;
        try {
            if (!videoView.isPlaying()) {
                videoView.start();
            }
        } catch (Exception ignored) {
        }
    }

    void pause() {
        paused = true;
        if (videoView == null) return;
        try {
            // Also clears VideoView's pending PLAYING target while preparing;
            // isPlaying() is false in that state, even after start() was called.
            videoView.pause();
        } catch (Exception ignored) {
        }
    }

    void stop() {
        paused = true;
        if (videoView == null) return;
        try {
            videoView.stopPlayback();
        } catch (Exception ignored) {
        }
        videoView = null;
    }

    private void scaleToCenterCrop(MediaPlayer player) {
        if (videoView == null) return;
        videoView.post(() -> {
            if (videoView == null || videoView.getWidth() <= 0 || videoView.getHeight() <= 0) return;
            int videoWidth = player.getVideoWidth();
            int videoHeight = player.getVideoHeight();
            int viewWidth = videoView.getWidth();
            int viewHeight = videoView.getHeight();
            if (videoWidth <= 0 || videoHeight <= 0) return;

            float scale = Math.max((float) viewWidth / videoWidth, (float) viewHeight / videoHeight);
            videoView.setScaleX((videoWidth * scale) / viewWidth);
            videoView.setScaleY((videoHeight * scale) / viewHeight);
        });
    }
}
