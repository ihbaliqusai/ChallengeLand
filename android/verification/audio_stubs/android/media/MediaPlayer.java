package android.media;

import android.content.Context;
import java.util.ArrayList;
import java.util.List;

/** Strict state checks make use-after-release and repeated releases fail tests. */
public final class MediaPlayer {
    public interface OnCompletionListener { void onCompletion(MediaPlayer player); }
    public interface OnErrorListener { boolean onError(MediaPlayer player, int what, int extra); }
    public static final List<MediaPlayer> CREATED = new ArrayList<>();
    public static int illegalAccesses;
    public static boolean failNextCreation;
    public final int resourceId;
    public final List<Float> volumes = new ArrayList<>();
    public boolean looping;
    public boolean playing;
    public boolean released;
    public int releases;
    private OnCompletionListener completionListener;
    private OnErrorListener errorListener;
    private MediaPlayer(int resourceId) { this.resourceId = resourceId; }
    public static MediaPlayer create(Context context, int resourceId) {
        if (failNextCreation) { failNextCreation = false; return null; }
        MediaPlayer player = new MediaPlayer(resourceId);
        CREATED.add(player);
        return player;
    }
    private void requireLive() {
        if (!released) return;
        illegalAccesses++;
        throw new IllegalStateException("Player already released");
    }
    public void setLooping(boolean value) { requireLive(); looping = value; }
    public void setVolume(float left, float right) { requireLive(); volumes.add(left); }
    public void setOnCompletionListener(OnCompletionListener listener) { requireLive(); completionListener = listener; }
    public void setOnErrorListener(OnErrorListener listener) { requireLive(); errorListener = listener; }
    public void start() { requireLive(); playing = true; }
    public boolean isPlaying() { requireLive(); return playing; }
    public void stop() { requireLive(); playing = false; }
    public void release() { requireLive(); released = true; playing = false; releases++; }
    public void complete() {
        requireLive();
        playing = false;
        if (completionListener != null) completionListener.onCompletion(this);
    }
    public void fail() {
        requireLive();
        if (errorListener != null) errorListener.onError(this, 1, 0);
    }
    public float volume() { return volumes.get(volumes.size() - 1); }
    public static MediaPlayer latest() { return CREATED.get(CREATED.size() - 1); }
    public static long liveCount() { return CREATED.stream().filter(player -> !player.released).count(); }
    public static void reset() {
        CREATED.clear();
        illegalAccesses = 0;
        failNextCreation = false;
    }
}
