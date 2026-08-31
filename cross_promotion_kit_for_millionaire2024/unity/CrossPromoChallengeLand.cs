using UnityEngine;

/// <summary>
/// سكربت ترويج للعبة "أرض التحدي" داخل محرك Unity للعبة "من سيربح المليون".
/// يمكن ربط دالة OnClickPromote() بأي زر في القائمة الرئيسية أو شاشة نهاية اللعبة.
/// </summary>
public class CrossPromoChallengeLand : MonoBehaviour
{
    private const string TARGET_PACKAGE = "com.qi7bali.landchallengeonline";
    private const string PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=" + TARGET_PACKAGE;

    public void OnClickPromote()
    {
#if UNITY_ANDROID && !UNITY_EDITOR
        try
        {
            using (AndroidJavaClass unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer"))
            using (AndroidJavaObject currentActivity = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity"))
            using (AndroidJavaObject packageManager = currentActivity.Call<AndroidJavaObject>("getPackageManager"))
            {
                AndroidJavaObject launchIntent = null;
                try
                {
                    launchIntent = packageManager.Call<AndroidJavaObject>("getLaunchIntentForPackage", TARGET_PACKAGE);
                }
                catch { }

                if (launchIntent != null)
                {
                    currentActivity.Call("startActivity", launchIntent);
                    return;
                }

                // If not installed, open Google Play
                try
                {
                    using (AndroidJavaClass uriClass = new AndroidJavaClass("android.net.Uri"))
                    using (AndroidJavaObject uri = uriClass.CallStatic<AndroidJavaObject>("parse", "market://details?id=" + TARGET_PACKAGE))
                    using (AndroidJavaObject marketIntent = new AndroidJavaObject("android.content.Intent", "android.intent.action.VIEW", uri))
                    {
                        marketIntent.Call<AndroidJavaObject>("addFlags", 0x10000000); // FLAG_ACTIVITY_NEW_TASK
                        currentActivity.Call("startActivity", marketIntent);
                        return;
                    }
                }
                catch
                {
                    Application.OpenURL(PLAY_STORE_URL);
                }
            }
        }
        catch (System.Exception e)
        {
            Debug.LogError("Error launching ChallengeLand: " + e.Message);
            Application.OpenURL(PLAY_STORE_URL);
        }
#else
        Application.OpenURL(PLAY_STORE_URL);
#endif
    }
}
