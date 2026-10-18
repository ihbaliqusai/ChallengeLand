package com.qi7bali.landchallengeonline

import android.content.Context
import android.view.View
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/** Shares the original chroma renderer and raw clips with the native game. */
class HomeCharacterViewFactory(
    private val activity: FlutterActivity,
    private val messenger: BinaryMessenger
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        HomeCharacterPlatformView(activity, messenger, viewId, args as? Map<*, *>)
}

private class HomeCharacterPlatformView(
    private val activity: FlutterActivity,
    messenger: BinaryMessenger,
    viewId: Int,
    args: Map<*, *>?
) : PlatformView, DefaultLifecycleObserver {
    private val clips = intArrayOf(
        R.raw.video_khaled, R.raw.video_omar, R.raw.video_fahad, R.raw.video_mazen,
        R.raw.video_mahmoud, R.raw.video_ellen, R.raw.video_sarah, R.raw.video_talia
    )
    private val index = ((args?.get("index") as? Number)?.toInt() ?: 1)
        .takeIf { it in clips.indices } ?: 1
    private val video = ChromaVideoView(activity, clips[index])
    private val channel = MethodChannel(messenger, "challengeland/home-character/$viewId")
    private var routePaused = args?.get("paused") as? Boolean ?: false
    private var activityPaused = !activity.lifecycle.currentState
        .isAtLeast(androidx.lifecycle.Lifecycle.State.RESUMED)
    private var disposed = false

    init {
        video.setPaused(routePaused || activityPaused)
        video.setOnFirstFrameListener { if (!disposed) channel.invokeMethod("ready", null) }
        channel.setMethodCallHandler { call, result ->
            if (call.method == "setPaused") {
                routePaused = call.arguments as? Boolean ?: true
                video.setPaused(routePaused || activityPaused)
                result.success(null)
            } else result.notImplemented()
        }
        activity.lifecycle.addObserver(this)
    }

    override fun getView(): View = video

    override fun onResume(owner: LifecycleOwner) {
        activityPaused = false
        video.setPaused(routePaused)
    }

    override fun onPause(owner: LifecycleOwner) {
        activityPaused = true
        video.setPaused(true)
    }

    override fun dispose() {
        if (disposed) return
        disposed = true
        channel.setMethodCallHandler(null)
        activity.lifecycle.removeObserver(this)
        video.release()
    }
}
