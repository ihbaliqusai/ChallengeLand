package com.qi7bali.landchallengeonline;

public final class GameViewportCheck {
    public static void main(String[] args) {
        int[][] displays = {{640, 360}, {800, 360}, {1280, 720}, {2340, 1080},
                {2560, 1600}, {1592, 826}, {1484, 826}, {360, 640}, {0, 0}};
        for (int[] display : displays) {
            float scale = GameViewportSpec.fitScale(display[0], display[1]);
            int density = GameViewportSpec.densityDpi(display[0], display[1]);
            if (density < 1 || (scale > 0 && density / 160f > scale + .001f)) {
                throw new AssertionError("Dialog density exceeds the available canvas");
            }
            if (scale > 0) {
                // The window can grow beyond 960x540; controls keep one scale.
                float widthDp = display[0] / (density / 160f);
                float heightDp = display[1] / (density / 160f);
                if (widthDp < GameViewportSpec.WIDTH_DP - .01f
                        || heightDp < GameViewportSpec.HEIGHT_DP - .01f) {
                    throw new AssertionError("Controls exceed usable bounds");
                }
            }
        }
        if (GameViewportSpec.densityDpi(1920, 1080) != 320) {
            throw new AssertionError("Expected a 2x canvas on Full HD");
        }
        if (GameViewportSpec.densityDpi(2340, 1080)
                != GameViewportSpec.densityDpi(1920, 1080)) {
            throw new AssertionError("A wider phone must not zoom the controls");
        }
        System.out.println("Game viewport checks passed");
    }
}
