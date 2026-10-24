package android.os;
public class Bundle {
    private final java.util.Map<String, Object> values = new java.util.HashMap<>();
    public boolean containsKey(String key) { return values.containsKey(key); }
    public String getString(String key) { return (String) values.get(key); }
    public void putString(String key, String value) { values.put(key, value); }
    public java.util.Set<String> keySet() { return values.keySet(); }
    public Object get(String key) { return values.get(key); }
    public void put(String key, Object value) { values.put(key, value); }
}
