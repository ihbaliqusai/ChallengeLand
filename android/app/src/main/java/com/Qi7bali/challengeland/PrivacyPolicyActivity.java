package com.qi7bali.landchallengeonline;

import android.graphics.Color;
import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.webkit.WebResourceRequest;
import android.widget.Toast;


public class PrivacyPolicyActivity extends GameViewportActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        supportRequestWindowFeature(Window.FEATURE_NO_TITLE);
        super.onCreate(savedInstanceState);
        getWindow().setFlags(
                WindowManager.LayoutParams.FLAG_FULLSCREEN,
                WindowManager.LayoutParams.FLAG_FULLSCREEN
        );
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_HIDE_NAVIGATION);
        setContentView(R.layout.activity_privacy_policy);
        if (getSupportActionBar() != null) getSupportActionBar().hide();

        View back = findViewById(R.id.btnPrivacyBack);
        WebView webView = findViewById(R.id.webPrivacyPolicy);
        android.widget.TextView title = findViewById(R.id.txtPrivacyTitle);
        View licenses = findViewById(R.id.btnPrivacyLicenses);

        back.setOnClickListener(v -> {
            if (webView.canGoBack()) {
                webView.goBack();
                title.setText("سياسة الخصوصية");
                licenses.setVisibility(View.VISIBLE);
            } else {
                finish();
            }
        });
        licenses.setOnClickListener(v -> {
            title.setText("تراخيص المكتبات والخطوط");
            licenses.setVisibility(View.GONE);
            webView.loadUrl("file:///android_asset/licenses/index.html");
        });

        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(false);
        settings.setDomStorageEnabled(false);
        settings.setAllowFileAccess(true);
        settings.setBuiltInZoomControls(true);
        settings.setDisplayZoomControls(false);

        webView.setBackgroundColor(Color.parseColor("#071330"));
        webView.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                if (!request.isForMainFrame()) return false;
                String scheme = request.getUrl().getScheme();
                if ("file".equals(scheme)) return false;
                if (!"https".equals(scheme) && !"mailto".equals(scheme)) return true;
                try {
                    startActivity(new Intent("mailto".equals(scheme)
                            ? Intent.ACTION_SENDTO : Intent.ACTION_VIEW, request.getUrl()));
                } catch (RuntimeException error) {
                    Toast.makeText(PrivacyPolicyActivity.this,
                            "تعذر فتح الرابط. يمكنك استخدام بريد التواصل الموضح في الصفحة.",
                            Toast.LENGTH_LONG).show();
                }
                return true;
            }
        });
        webView.loadUrl("file:///android_asset/privacy_policy_ar.html");
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) {
            getWindow().getDecorView().setSystemUiVisibility(
                    View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                            | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                            | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                            | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                            | View.SYSTEM_UI_FLAG_FULLSCREEN
                            | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            );
        }
    }
}
