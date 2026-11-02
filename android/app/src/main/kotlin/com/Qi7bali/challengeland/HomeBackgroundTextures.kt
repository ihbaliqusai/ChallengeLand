package com.qi7bali.landchallengeonline

import android.media.MediaPlayer
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.view.Surface
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

/** Opaque hardware-decoded lobby video. No platform view or chroma-key pass. */
class HomeBackgroundTextures(
    private val activity: FlutterActivity,
    private val textures: TextureRegistry,
    private val messenger: BinaryMessenger
) : DefaultLifecycleObserver {
    private val main = Handler(Looper.getMainLooper())
    private val sessions = mutableMapOf<Long, Session>()
    private val factory = MethodChannel(messenger, "challengeland/home-background")

    init {
        activity.lifecycle.addObserver(this)
        factory.setMethodCallHandler { call, result ->
            if (call.method != "create") {
                result.notImplemented()
            } else {
                try {
                    val session = Session()
                    sessions[session.entry.id()] = session
                    result.success(session.entry.id())
                } catch (error: Exception) {
                    result.error("HOME_BACKGROUND", error.message, null)
                }
            }
        }
    }

    private inner class Session {
        val entry = textures.createSurfaceProducer()
        private var surface: Surface? = null // Player-thread ownership after init.
        private val thread = HandlerThread("LobbyVideo")
        private val handler: Handler
        private val methods = MethodChannel(messenger,
            "challengeland/home-background/${entry.id()}")
        private var routePaused = true
        private var disposed = false // Main-thread session ownership.
        // The following fields are owned by the player thread only.
        private var player: MediaPlayer? = null
        private var prepared = false
        private var paused = true

        init {
            entry.setSize(960, 540)
            surface = entry.surface
            thread.start()
            handler = Handler(thread.looper)
            entry.setCallback(object : TextureRegistry.SurfaceProducer.Callback {
                override fun onSurfaceAvailable() {
                    if (disposed) return
                    val next = entry.surface
                    handler.post {
                        surface = next
                        try { player?.setSurface(next) } catch (_: IllegalStateException) {}
                        applyPaused()
                    }
                }

                override fun onSurfaceCleanup() {
                    handler.post {
                        surface = null
                        try {
                            if (prepared) player?.pause()
                            player?.setSurface(null)
                        } catch (_: IllegalStateException) {}
                    }
                }
            })
            methods.setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        routePaused = call.arguments as? Boolean ?: false
                        updatePaused()
                        handler.post { prepare() }
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

        private fun notify(method: String) {
            main.post { if (!disposed) methods.invokeMethod(method, null) }
        }

        private fun prepare() {
            if (player != null) return
            try {
                val media = MediaPlayer()
                player = media
                activity.resources.openRawResourceFd(R.raw.home_background).use { fd ->
                    media.setDataSource(fd.fileDescriptor, fd.startOffset, fd.length)
                }
                media.setSurface(surface)
                media.isLooping = true
                media.setVolume(0f, 0f)
                media.setOnPreparedListener {
                    prepared = true
                    applyPaused()
                }
                media.setOnInfoListener { _, what, _ ->
                    if (what == MediaPlayer.MEDIA_INFO_VIDEO_RENDERING_START) notify("ready")
                    false
                }
                media.setOnErrorListener { _, _, _ ->
                    prepared = false
                    notify("failed")
                    true
                }
                media.prepareAsync()
            } catch (_: Exception) {
                prepared = false
                notify("failed")
            }
        }

        fun updatePaused() {
            val value = routePaused || !activity.lifecycle.currentState
                .isAtLeast(Lifecycle.State.RESUMED)
            handler.post {
                paused = value
                applyPaused()
            }
        }

        private fun applyPaused() {
            val media = player ?: return
            if (!prepared) return
            try {
                if (paused || surface == null) media.pause()
                else if (!media.isPlaying) media.start()
            } catch (_: IllegalStateException) {
                notify("failed")
            }
        }

        fun dispose() {
            if (disposed) return
            disposed = true
            sessions.remove(entry.id())
            methods.setMethodCallHandler(null)
            entry.setCallback(null)
            // Release the producer before Flutter frees its consumer texture.
            handler.post {
                player?.setOnPreparedListener(null)
                player?.setOnInfoListener(null)
                player?.setOnErrorListener(null)
                player?.release()
                player = null
                val output = surface
                surface = null // SurfaceProducer owns and releases the Surface.
                main.post { FlutterTextureRelease.release(entry, output) }
                thread.quitSafely()
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
        factory.setMethodCallHandler(null)
        sessions.values.toList().forEach { it.dispose() }
        activity.lifecycle.removeObserver(this)
    }
}
