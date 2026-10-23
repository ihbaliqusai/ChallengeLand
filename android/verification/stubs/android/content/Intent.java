package android.content;
public class Intent {
    public Intent() {}
    public Intent(Context context, Class<?> target) {}
    private final java.util.Map<String, Object> extras = new java.util.HashMap<>();
    public boolean hasExtra(String key) { return extras.containsKey(key); }
    public String getStringExtra(String key) { return (String) extras.get(key); }
    public boolean getBooleanExtra(String key, boolean fallback) { return (Boolean) extras.getOrDefault(key, fallback); }
    public int getIntExtra(String key, int fallback) { return (Integer) extras.getOrDefault(key, fallback); }
    public Intent putExtra(String key, String value) { extras.put(key, value); return this; }
    public Intent putExtra(String key, boolean value) { extras.put(key, value); return this; }
    public Intent putExtra(String key, int value) { extras.put(key, value); return this; }
    public Intent putExtra(String key, long value) { extras.put(key, value); return this; }
    public android.os.Bundle getExtras() {
        android.os.Bundle result = new android.os.Bundle();
        for (java.util.Map.Entry<String, Object> entry : extras.entrySet()) result.put(entry.getKey(), entry.getValue());
        return result;
    }
}
