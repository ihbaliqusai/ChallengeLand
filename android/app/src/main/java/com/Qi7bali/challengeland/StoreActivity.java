package com.qi7bali.landchallengeonline;

import android.content.Intent;
import android.os.Bundle;
import androidx.appcompat.app.AppCompatActivity;

/** Legacy game entry points use the same Flutter store and purchase flow. */
public class StoreActivity extends AppCompatActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Intent storeIntent = new Intent(this, MainActivity.class);
        storeIntent.putExtra("launchAction", "open_store");
        storeIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        startActivity(storeIntent);
        finish();
    }
}
