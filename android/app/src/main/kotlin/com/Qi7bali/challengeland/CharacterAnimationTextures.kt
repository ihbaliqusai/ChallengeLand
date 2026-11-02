package com.qi7bali.landchallengeonline

import android.view.Surface
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
        R.raw.character_preview_khaled, R.raw.character_preview_omar,
        R.raw.character_preview_fahad, R.raw.character_preview_mazen,
        R.raw.character_preview_mahmoud, R.raw.character_preview_ellen,
        R.raw.character_preview_sarah, R.raw.character_preview_talia,
        R.raw.character_preview_layan, R.raw.character_preview_rashid,
        R.raw.character_preview_jana, R.raw.character_preview_yazan,
        R.raw.character_preview_nour, R.raw.character_preview_zaid,
        R.raw.character_preview_salman, R.raw.character_preview_adam
    )

    init {
        activity.lifecycle.addObserver(this)
        channel.setMethodCallHandler { call, result ->
            if (call.method == "create") {
                val index = (call.argument<Number>("index")?.toInt() ?: 1)
                    .takeIf { it in clips.indices } ?: 1
                try {
                    val session = Session(index, call.argument<Boolean>("reflection") ?: true)
                    sessions[session.entry.id()] = session
                    result.success(buildMap {
                        put("original", session.entry.id())
                        session.reflectionEntry?.let { put("reflection", it.id()) }
                    })
                } catch (error: Exception) {
                    result.error("CHARACTER_TEXTURE", error.message, null)
                }
            } else result.notImplemented()
        }
    }

    private inner class Session(index: Int, includeReflection: Boolean) {
        // Only the single large preview uses this tier. The eight game seats
        // retain their independent 360x640 videos and lower decoder budget.
        val entry = textures.createSurfaceProducer().apply { setSize(540, 960) }
        val reflectionEntry = if (includeReflection) textures.createSurfaceProducer()
            .apply { setSize(270, 480) } else null
        private val clip = clips[index]
        private var video: ChromaVideoView? = null
        private var outputSurface: Surface? = null
        private var reflectionSurface: Surface? = null
        private val methods = MethodChannel(messenger,
            "challengeland/character-animation/${entry.id()}")
        private var routePaused = false
        private var disposed = false
        private var started = false
        private var releasing = false
        private var entriesReleased = false
        private var originalAvailable = true
        private var reflectionAvailable = true

        init {
            entry.setCallback(surfaceCallbacks(false))
            reflectionEntry?.setCallback(surfaceCallbacks(true))
            methods.setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        routePaused = call.argument<Boolean>("paused") ?: false
                        started = true
                        updatePaused()
                        startRenderer()
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

        private fun surfaceCallbacks(reflected: Boolean) =
            object : TextureRegistry.SurfaceProducer.Callback {
                override fun onSurfaceAvailable() {
                    if (reflected) reflectionAvailable = true else originalAvailable = true
                    startRenderer()
                }

                override fun onSurfaceCleanup() {
                    if (reflected) reflectionAvailable = false else originalAvailable = false
                    stopRenderer()
                }
            }

        private fun startRenderer() {
            if (disposed || !started || releasing || video != null ||
                !originalAvailable || !reflectionAvailable) return
            val renderer = ChromaVideoView(activity, clip)
            video = renderer
            updatePaused()
            outputSurface = entry.surface
            reflectionSurface = reflectionEntry?.surface
            renderer.startSurfaceOutputs(outputSurface, reflectionSurface, 540, 960) {
                if (!disposed && video === renderer) methods.invokeMethod("ready", null)
            }
        }

        private fun stopRenderer() {
            val renderer = video
            video = null
            if (renderer == null) {
                if (disposed && !releasing) releaseEntries()
                return
            }
            releasing = true
            renderer.releaseTextureOutput {
                releasing = false
                if (disposed) releaseEntries() else startRenderer()
            }
        }

        private fun releaseEntries() {
            if (entriesReleased) return
            entriesReleased = true
            FlutterTextureRelease.release(entry, outputSurface)
            reflectionEntry?.let { FlutterTextureRelease.release(it, reflectionSurface) }
            outputSurface = null
            reflectionSurface = null
        }

        fun updatePaused() {
            video?.setPaused(routePaused || !activity.lifecycle.currentState
                .isAtLeast(androidx.lifecycle.Lifecycle.State.RESUMED))
        }

        fun dispose() {
            if (disposed) return
            disposed = true
            methods.setMethodCallHandler(null)
            entry.setCallback(null)
            reflectionEntry?.setCallback(null)
            sessions.remove(entry.id())
            // EGL must release its producer before Flutter releases the texture.
            stopRenderer()
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
