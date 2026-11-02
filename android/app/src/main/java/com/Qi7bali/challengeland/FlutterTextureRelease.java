package com.qi7bali.landchallengeonline;

import android.view.Surface;
import io.flutter.view.TextureRegistry;

/** Completes asynchronous producer cleanup even when its Flutter engine exited. */
final class FlutterTextureRelease {
    private FlutterTextureRelease() {}

    static void release(TextureRegistry.SurfaceProducer producer, Surface surface) {
        try {
            producer.release();
        } catch (RuntimeException error) {
            // Flutter 3.32's ImageReader producer closes its Java surfaces first,
            // then unregisters the texture through JNI. The GL/player teardown
            // may finish after engine destruction, which already freed that
            // native texture. Only that final, redundant unregister may fail.
            if (!"Cannot execute operation because FlutterJNI is not attached to native."
                    .equals(error.getMessage())) {
                throw error;
            }
            // The older GL-backed producer unregisters before releasing its
            // Surface. Keep that handle available for the detached-engine case.
            if (surface != null) surface.release();
        }
    }
}
