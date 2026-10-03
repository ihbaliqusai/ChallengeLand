package com.qi7bali.landchallengeonline;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;

/** Debug-only local destination for Ad Inspector's request export. */
public final class AdRequestCaptureActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        try {
            if (Intent.ACTION_SEND.equals(getIntent().getAction())) {
                String request = getIntent().getStringExtra(Intent.EXTRA_TEXT);
                if (request != null && !request.isEmpty()) {
                    File output = new File(getFilesDir(), "admob-request.txt");
                    try (FileOutputStream stream = new FileOutputStream(output)) {
                        stream.write(request.getBytes(StandardCharsets.UTF_8));
                    }
                    Log.i("AdRequestCapture", "Saved Ad Inspector request locally.");
                }
            }
        } catch (Exception error) {
            Log.w("AdRequestCapture", "Could not save request", error);
        } finally {
            finish();
        }
    }
}
