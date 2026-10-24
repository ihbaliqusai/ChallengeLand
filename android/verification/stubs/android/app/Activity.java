package android.app;
import android.content.Context;
import android.content.Intent;
public abstract class Activity extends Context {
    private final Intent intent = new Intent();
    public Intent getIntent() { return intent; }
    public Intent lastStartedIntent;
    public void startActivity(Intent intent) { lastStartedIntent = intent; }
}
