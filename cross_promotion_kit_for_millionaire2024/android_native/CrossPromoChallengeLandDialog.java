package net.androidgaming.millionaire2024; // غيّر هذا إلى package مشروعك إذا لزم الأمر

import android.app.Activity;
import android.app.Dialog;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.view.View;
import android.view.Window;
import android.widget.Button;
import android.widget.ImageButton;
import android.widget.TextView;

/**
 * نافذة ترويجية فاخرة لعرض لعبة "أرض التحدي - أونلاين" داخل لعبة "من سيربح المليون 2024".
 * 
 * طريقة الاستخدام البسيطة:
 * CrossPromoChallengeLandDialog.show(activity);
 */
public class CrossPromoChallengeLandDialog extends Dialog {

    public static final String TARGET_PACKAGE = "com.qi7bali.landchallengeonline";
    public static final String PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=" + TARGET_PACKAGE;

    private final Activity activity;

    public static void show(Activity activity) {
        if (activity == null || activity.isFinishing()) return;
        try {
            CrossPromoChallengeLandDialog dialog = new CrossPromoChallengeLandDialog(activity);
            dialog.show();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public CrossPromoChallengeLandDialog(Activity activity) {
        super(activity);
        this.activity = activity;
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        setContentView(R.layout.dialog_cross_promo_challengeland);

        if (getWindow() != null) {
            getWindow().setBackgroundDrawable(new ColorDrawable(Color.TRANSPARENT));
        }

        final boolean isInstalled = isAppInstalled(activity, TARGET_PACKAGE);

        Button btnAction = findViewById(R.id.btnCrossPromoAction);
        ImageButton btnClose = findViewById(R.id.btnCrossPromoClose);

        if (btnAction != null) {
            if (isInstalled) {
                btnAction.setText("فتح أرض التحدي 🎮");
            } else {
                btnAction.setText("تثبيت مجاناً من Google Play 🚀");
            }

            btnAction.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    launchTargetAppOrStore(activity, TARGET_PACKAGE, PLAY_STORE_URL);
                    dismiss();
                }
            });
        }

        if (btnClose != null) {
            btnClose.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    dismiss();
                }
            });
        }
    }

    public static boolean isAppInstalled(Context context, String packageName) {
        if (context == null || packageName == null) return false;
        PackageManager pm = context.getPackageManager();
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0));
            } else {
                pm.getPackageInfo(packageName, 0);
            }
            return true;
        } catch (PackageManager.NameNotFoundException e) {
            return false;
        }
    }

    public static void launchTargetAppOrStore(Context context, String packageName, String fallbackUrl) {
        if (context == null) return;
        PackageManager pm = context.getPackageManager();
        Intent launchIntent = pm.getLaunchIntentForPackage(packageName);
        if (launchIntent != null) {
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(launchIntent);
        } else {
            try {
                Intent marketIntent = new Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=" + packageName));
                marketIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                context.startActivity(marketIntent);
            } catch (Exception e) {
                Intent webIntent = new Intent(Intent.ACTION_VIEW, Uri.parse(fallbackUrl));
                webIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                context.startActivity(webIntent);
            }
        }
    }
}
