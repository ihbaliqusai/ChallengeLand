package com.qi7bali.landchallengeonline;

import android.content.Context;
import android.content.res.AssetFileDescriptor;
import android.graphics.SurfaceTexture;
import android.media.MediaPlayer;
import android.opengl.EGL14;
import android.opengl.EGLConfig;
import android.opengl.EGLContext;
import android.opengl.EGLDisplay;
import android.opengl.EGLSurface;
import android.opengl.GLES11Ext;
import android.opengl.GLES20;
import android.os.Handler;
import android.os.HandlerThread;
import android.util.Log;
import android.view.Surface;
import android.view.TextureView;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;
import java.util.concurrent.CountDownLatch;

/**
 * A {@link TextureView} that plays a looping, muted clip from {@code res/raw} and
 * keys out its solid black background (alpha = 0) so only the animated character
 * remains, compositing over the studio scene exactly like the static contestant
 * PNGs do.
 *
 * <p>MP4 cannot carry an alpha channel, so the artwork ships on a pure-black
 * background; a tiny OpenGL ES fragment shader turns near-black pixels
 * transparent at draw time. All GL/MediaPlayer work happens on a dedicated
 * thread tied to the surface lifecycle, so backgrounding the activity or
 * rebuilding the contestant row releases everything cleanly.
 */
final class ChromaVideoView extends TextureView
        implements TextureView.SurfaceTextureListener, SurfaceTexture.OnFrameAvailableListener {

    private static final String TAG = "ChromaVideoView";

    private static final String VERTEX_SHADER =
            "uniform mat4 uSTMatrix;\n" +
            "attribute vec4 aPosition;\n" +
            "attribute vec2 aTexCoord;\n" +
            "varying vec2 vTex;\n" +
            "void main() {\n" +
            "  gl_Position = aPosition;\n" +
            "  vTex = (uSTMatrix * vec4(aTexCoord, 0.0, 1.0)).xy;\n" +
            "}\n";

    // Keys out the black backdrop: alpha ramps from 0 (near-black) to 1, using the
    // brightest channel so dark-but-coloured clothing is kept. Premultiplied output
    // pairs with GL_ONE / GL_ONE_MINUS_SRC_ALPHA for clean (fringe-free) edges.
    private static final String FRAGMENT_SHADER =
            "#extension GL_OES_EGL_image_external : require\n" +
            "precision mediump float;\n" +
            "varying vec2 vTex;\n" +
            "uniform samplerExternalOES sTexture;\n" +
            "void main() {\n" +
            "  vec4 c = texture2D(sTexture, vTex);\n" +
            "  float luma = max(c.r, max(c.g, c.b));\n" +
            "  float alpha = smoothstep(0.05, 0.18, luma);\n" +
            "  gl_FragColor = vec4(c.rgb * alpha, alpha);\n" +
            "}\n";

    private static final float[] QUAD_POS = {-1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f};
    private static final float[] QUAD_TEX = {0f, 0f, 1f, 0f, 0f, 1f, 1f, 1f};

    private final int idleResId;
    private int currentResId;
    private volatile boolean released;

    private HandlerThread glThread;
    private Handler glHandler;

    // Everything below is touched only on glThread.
    private EGLDisplay eglDisplay = EGL14.EGL_NO_DISPLAY;
    private EGLContext eglContext = EGL14.EGL_NO_CONTEXT;
    private EGLSurface eglSurface = EGL14.EGL_NO_SURFACE;
    private int program;
    private int aPositionLoc;
    private int aTexCoordLoc;
    private int uSTMatrixLoc;
    private int oesTexId;
    private SurfaceTexture videoTexture;
    private Surface videoSurface;
    private MediaPlayer player;
    private boolean frameReady;
    private final float[] stMatrix = new float[16];
    private FloatBuffer posBuffer;
    private FloatBuffer texBuffer;
    private int viewWidth;
    private int viewHeight;

    ChromaVideoView(Context context, int idleResId) {
        super(context);
        this.idleResId = idleResId;
        setOpaque(false);
        setSurfaceTextureListener(this);
    }

    /** Permanently tears the view down; safe to call from the main thread. */
    void release() {
        released = true;
        setSurfaceTextureListener(null);
        stopGl();
    }

    // ---- SurfaceTextureListener (main thread) --------------------------------

    @Override
    public void onSurfaceTextureAvailable(SurfaceTexture surface, int width, int height) {
        if (released) {
            return;
        }
        viewWidth = width;
        viewHeight = height;
        glThread = new HandlerThread("ChromaGL");
        glThread.start();
        glHandler = new Handler(glThread.getLooper());
        glHandler.post(() -> initGl(surface));
    }

    @Override
    public void onSurfaceTextureSizeChanged(SurfaceTexture surface, int width, int height) {
        viewWidth = width;
        viewHeight = height;
    }

    @Override
    public boolean onSurfaceTextureDestroyed(SurfaceTexture surface) {
        stopGl();
        return true;
    }

    @Override
    public void onSurfaceTextureUpdated(SurfaceTexture surface) {
        // Output surface; nothing to do.
    }

    // ---- Frame callback (glThread) -------------------------------------------

    @Override
    public void onFrameAvailable(SurfaceTexture surfaceTexture) {
        frameReady = true;
        drawFrame();
    }

    // ---- GL thread work ------------------------------------------------------

    private void initGl(SurfaceTexture outputSurface) {
        try {
            setupEgl(outputSurface);
            program = buildProgram(VERTEX_SHADER, FRAGMENT_SHADER);
            aPositionLoc = GLES20.glGetAttribLocation(program, "aPosition");
            aTexCoordLoc = GLES20.glGetAttribLocation(program, "aTexCoord");
            uSTMatrixLoc = GLES20.glGetUniformLocation(program, "uSTMatrix");
            posBuffer = toBuffer(QUAD_POS);
            texBuffer = toBuffer(QUAD_TEX);

            int[] tex = new int[1];
            GLES20.glGenTextures(1, tex, 0);
            oesTexId = tex[0];
            GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, oesTexId);
            GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
                    GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR);
            GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
                    GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR);
            GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
                    GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE);
            GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
                    GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE);

            GLES20.glEnable(GLES20.GL_BLEND);
            GLES20.glBlendFunc(GLES20.GL_ONE, GLES20.GL_ONE_MINUS_SRC_ALPHA);
            GLES20.glClearColor(0f, 0f, 0f, 0f);

            videoTexture = new SurfaceTexture(oesTexId);
            videoTexture.setOnFrameAvailableListener(this, glHandler);
            videoSurface = new Surface(videoTexture);

            player = new MediaPlayer();
            playClip(idleResId, true);
        } catch (Exception e) {
            Log.w(TAG, "initGl failed", e);
            teardown();
        }
    }

    /**
     * Plays a one-shot reaction clip (e.g. correct / wrong answer) and then returns
     * to the looping idle clip. No-op if the surface is not ready yet or resId is 0.
     */
    void playReaction(int resId) {
        if (resId == 0) {
            return;
        }
        final Handler handler = glHandler;
        if (handler == null) {
            return;
        }
        handler.post(() -> playClip(resId, false));
    }

    /** Returns to the looping idle clip if a reaction is currently showing. */
    void resetToIdle() {
        final Handler handler = glHandler;
        if (handler == null) {
            return;
        }
        handler.post(() -> {
            if (currentResId != idleResId) {
                playClip(idleResId, true);
            }
        });
    }

    /** Swaps the playing clip (runs on glThread). When {@code loop} is false the clip
     *  plays once and then auto-returns to the idle clip. */
    private void playClip(int resId, boolean loop) {
        if (player == null || videoSurface == null) {
            return;
        }
        try {
            player.reset();
            AssetFileDescriptor afd = getContext().getResources().openRawResourceFd(resId);
            player.setDataSource(afd.getFileDescriptor(), afd.getStartOffset(), afd.getLength());
            afd.close();
            player.setSurface(videoSurface);
            player.setVolume(0f, 0f);
            player.setLooping(loop);
            player.setOnPreparedListener(mp -> {
                if (!released) {
                    mp.start();
                }
            });
            player.setOnCompletionListener(mp -> {
                if (!released && !loop) {
                    playClip(idleResId, true);
                }
            });
            currentResId = resId;
            player.prepareAsync();
        } catch (Exception e) {
            Log.w(TAG, "playClip failed", e);
        }
    }

    private void drawFrame() {
        if (released || eglDisplay == EGL14.EGL_NO_DISPLAY || videoTexture == null || !frameReady) {
            return;
        }
        try {
            videoTexture.updateTexImage();
            videoTexture.getTransformMatrix(stMatrix);

            GLES20.glViewport(0, 0, viewWidth, viewHeight);
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT);
            GLES20.glUseProgram(program);

            GLES20.glActiveTexture(GLES20.GL_TEXTURE0);
            GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, oesTexId);

            posBuffer.position(0);
            GLES20.glVertexAttribPointer(aPositionLoc, 2, GLES20.GL_FLOAT, false, 0, posBuffer);
            GLES20.glEnableVertexAttribArray(aPositionLoc);
            texBuffer.position(0);
            GLES20.glVertexAttribPointer(aTexCoordLoc, 2, GLES20.GL_FLOAT, false, 0, texBuffer);
            GLES20.glEnableVertexAttribArray(aTexCoordLoc);

            GLES20.glUniformMatrix4fv(uSTMatrixLoc, 1, false, stMatrix, 0);
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4);

            GLES20.glDisableVertexAttribArray(aPositionLoc);
            GLES20.glDisableVertexAttribArray(aTexCoordLoc);

            EGL14.eglSwapBuffers(eglDisplay, eglSurface);
        } catch (Exception e) {
            Log.w(TAG, "drawFrame failed", e);
        }
    }

    // ---- teardown ------------------------------------------------------------

    private void stopGl() {
        final HandlerThread thread = glThread;
        final Handler handler = glHandler;
        glThread = null;
        glHandler = null;
        if (thread == null || handler == null) {
            return;
        }
        final CountDownLatch latch = new CountDownLatch(1);
        handler.post(() -> {
            try {
                teardown();
            } finally {
                latch.countDown();
            }
        });
        try {
            latch.await(600, java.util.concurrent.TimeUnit.MILLISECONDS);
        } catch (InterruptedException ignored) {
            Thread.currentThread().interrupt();
        }
        thread.quitSafely();
    }

    private void teardown() {
        if (player != null) {
            try {
                player.stop();
            } catch (Exception ignored) {
                // player may not be started yet
            }
            player.release();
            player = null;
        }
        if (videoSurface != null) {
            videoSurface.release();
            videoSurface = null;
        }
        if (videoTexture != null) {
            videoTexture.setOnFrameAvailableListener(null);
            videoTexture.release();
            videoTexture = null;
        }
        if (program != 0) {
            GLES20.glDeleteProgram(program);
            program = 0;
        }
        if (oesTexId != 0) {
            GLES20.glDeleteTextures(1, new int[]{oesTexId}, 0);
            oesTexId = 0;
        }
        if (eglDisplay != EGL14.EGL_NO_DISPLAY) {
            EGL14.eglMakeCurrent(eglDisplay, EGL14.EGL_NO_SURFACE,
                    EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT);
            if (eglSurface != EGL14.EGL_NO_SURFACE) {
                EGL14.eglDestroySurface(eglDisplay, eglSurface);
            }
            if (eglContext != EGL14.EGL_NO_CONTEXT) {
                EGL14.eglDestroyContext(eglDisplay, eglContext);
            }
            EGL14.eglReleaseThread();
            EGL14.eglTerminate(eglDisplay);
        }
        eglSurface = EGL14.EGL_NO_SURFACE;
        eglContext = EGL14.EGL_NO_CONTEXT;
        eglDisplay = EGL14.EGL_NO_DISPLAY;
        frameReady = false;
    }

    // ---- EGL / GL helpers ----------------------------------------------------

    private void setupEgl(SurfaceTexture outputSurface) {
        eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY);
        if (eglDisplay == EGL14.EGL_NO_DISPLAY) {
            throw new RuntimeException("eglGetDisplay failed");
        }
        int[] version = new int[2];
        if (!EGL14.eglInitialize(eglDisplay, version, 0, version, 1)) {
            throw new RuntimeException("eglInitialize failed");
        }
        int[] configAttribs = {
                EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                EGL14.EGL_RED_SIZE, 8,
                EGL14.EGL_GREEN_SIZE, 8,
                EGL14.EGL_BLUE_SIZE, 8,
                EGL14.EGL_ALPHA_SIZE, 8,
                EGL14.EGL_NONE
        };
        EGLConfig[] configs = new EGLConfig[1];
        int[] numConfigs = new int[1];
        if (!EGL14.eglChooseConfig(eglDisplay, configAttribs, 0, configs, 0, 1, numConfigs, 0)
                || numConfigs[0] <= 0) {
            throw new RuntimeException("eglChooseConfig failed");
        }
        int[] contextAttribs = {EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE};
        eglContext = EGL14.eglCreateContext(eglDisplay, configs[0],
                EGL14.EGL_NO_CONTEXT, contextAttribs, 0);
        if (eglContext == EGL14.EGL_NO_CONTEXT) {
            throw new RuntimeException("eglCreateContext failed");
        }
        eglSurface = EGL14.eglCreateWindowSurface(eglDisplay, configs[0], outputSurface,
                new int[]{EGL14.EGL_NONE}, 0);
        if (eglSurface == EGL14.EGL_NO_SURFACE) {
            throw new RuntimeException("eglCreateWindowSurface failed");
        }
        if (!EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)) {
            throw new RuntimeException("eglMakeCurrent failed");
        }
    }

    private static int buildProgram(String vertexSrc, String fragmentSrc) {
        int vs = compileShader(GLES20.GL_VERTEX_SHADER, vertexSrc);
        int fs = compileShader(GLES20.GL_FRAGMENT_SHADER, fragmentSrc);
        int prog = GLES20.glCreateProgram();
        GLES20.glAttachShader(prog, vs);
        GLES20.glAttachShader(prog, fs);
        GLES20.glLinkProgram(prog);
        int[] status = new int[1];
        GLES20.glGetProgramiv(prog, GLES20.GL_LINK_STATUS, status, 0);
        if (status[0] != GLES20.GL_TRUE) {
            String log = GLES20.glGetProgramInfoLog(prog);
            GLES20.glDeleteProgram(prog);
            throw new RuntimeException("Program link failed: " + log);
        }
        GLES20.glDeleteShader(vs);
        GLES20.glDeleteShader(fs);
        return prog;
    }

    private static int compileShader(int type, String src) {
        int shader = GLES20.glCreateShader(type);
        GLES20.glShaderSource(shader, src);
        GLES20.glCompileShader(shader);
        int[] status = new int[1];
        GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, status, 0);
        if (status[0] != GLES20.GL_TRUE) {
            String log = GLES20.glGetShaderInfoLog(shader);
            GLES20.glDeleteShader(shader);
            throw new RuntimeException("Shader compile failed: " + log);
        }
        return shader;
    }

    private static FloatBuffer toBuffer(float[] data) {
        FloatBuffer buffer = ByteBuffer.allocateDirect(data.length * 4)
                .order(ByteOrder.nativeOrder())
                .asFloatBuffer();
        buffer.put(data).position(0);
        return buffer;
    }
}
