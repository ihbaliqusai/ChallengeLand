package android.content;
public class Intent {
    private final java.util.Map<String, Object> extras = new java.util.HashMap<>();
    public boolean hasExtra(String key) { return extras.containsKey(key); }
    public String getStringExtra(String key) { return (String) extras.get(key); }
    public boolean getBooleanExtra(String key, boolean fallback) { return (Boolean) extras.getOrDefault(key, fallback); }
    public int getIntExtra(String key, int fallback) { return (Integer) extras.getOrDefault(key, fallback); }
    public Intent putExtra(String key, String value) { extras.put(key, value); return this; }
    public Intent putExtra(String key, boolean value) { extras.put(key, value); return this; }
    public Intent putExtra(String key, int value) { extras.put(key, value); return this; }
}
