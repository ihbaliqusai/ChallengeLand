package com.qi7bali.landchallengeonline

import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

/** One decoder publishes each frame to separate standing/reflection textures. */
class CharacterAnimationTextures(
    private val activity: FlutterActivity,
    private val textures: TextureRegistry,
    private val messenger: BinaryMessenger
) : DefaultLifecycleObserver {
    private val sessions = mutableMapOf<Long, Session>()
    private val channel = MethodChannel(messenger, "challengeland/character-animation")
    private val clips = intArrayOf(
        R.raw.video_khaled, R.raw.video_omar, R.raw.video_fahad, R.raw.video_mazen,
        R.raw.video_mahmoud, R.raw.video_ellen, R.raw.video_sarah, R.raw.video_talia,
        R.raw.video_layan, R.raw.video_rashid, R.raw.video_jana, R.raw.video_yazan,
        R.raw.video_nour, R.raw.video_zaid, R.raw.video_salman, R.raw.video_adam
    )

    init {
        activity.lifecycle.addObserver(this)
        channel.setMethodCallHandler { call, result ->
            if (call.method == "create") {
                val index = (call.argument<Number>("index")?.toInt() ?: 1)
                    .takeIf { it in clips.indices } ?: 1
                try {
                    val session = Session(index)
                    sessions[session.entry.id()] = session
                    result.success(mapOf("original" to session.entry.id(),
                        "reflection" to session.reflectionEntry.id()))
                } catch (error: Exception) {
                    result.error("CHARACTER_TEXTURE", error.message, null)
                }
            } else result.notImplemented()
        }
    }

    private inner class Session(index: Int) {
        val entry = textures.createSurfaceTexture()
        val reflectionEntry = textures.createSurfaceTexture()
        private val video = ChromaVideoView(activity, clips[index])
        private val methods = MethodChannel(messenger,
            "challengeland/character-animation/${entry.id()}")
        private var routePaused = false
        private var disposed = false

        init {
            methods.setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        routePaused = call.argument<Boolean>("paused") ?: false
                        updatePaused()
                        video.startTextureOutputs(entry.surfaceTexture(),
                            reflectionEntry.surfaceTexture(), 540, 960) {
                            if (!disposed) methods.invokeMethod("ready", null)
                        }
                        result.success(null)
                    }
                    "setPaused" -> {
                        routePaused = call.arguments as? Boolean ?: true
                        updatePaused()
                        result.success(null)
                    }
                    "dispose" -> {
                        dispose()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        fun updatePaused() {
            video.setPaused(routePaused || !activity.lifecycle.currentState
                .isAtLeast(androidx.lifecycle.Lifecycle.State.RESUMED))
        }

        fun dispose() {
            if (disposed) return
            disposed = true
            methods.setMethodCallHandler(null)
            sessions.remove(entry.id())
            // EGL must release its producer before Flutter releases the texture.
            video.releaseTextureOutput {
                entry.release()
                reflectionEntry.release()
            }
        }
    }

    override fun onResume(owner: LifecycleOwner) {
        sessions.values.forEach { it.updatePaused() }
    }

    override fun onPause(owner: LifecycleOwner) {
        sessions.values.forEach { it.updatePaused() }
    }

    override fun onDestroy(owner: LifecycleOwner) {
        channel.setMethodCallHandler(null)
        sessions.values.toList().forEach { it.dispose() }
        activity.lifecycle.removeObserver(this)
    }
}
