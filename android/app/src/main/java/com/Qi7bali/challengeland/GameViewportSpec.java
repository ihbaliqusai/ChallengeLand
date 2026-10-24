package com.qi7bali.landchallengeonline;

/** Reference control sizes; the actual canvas grows to match the window. */
final class GameViewportSpec {
    static final int WIDTH_DP = 960;
    static final int HEIGHT_DP = 540;

    private GameViewportSpec() {}

    static float fitScale(int width, int height) {
        return Math.max(0f, Math.min(width / (float) WIDTH_DP,
                height / (float) HEIGHT_DP));
    }

    static int densityDpi(int width, int height) {
        // Round down so dp-based dialogs also fit within the game canvas.
        return Math.max(1, (int) Math.floor(fitScale(width, height) * 160f));
    }
}
