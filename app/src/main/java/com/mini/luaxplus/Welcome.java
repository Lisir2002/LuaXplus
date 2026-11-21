package com.mini.luaxplus;

import android.app.Activity;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.androlua.Main;

/**
 * 品牌启动页：展示应用标识后进入编辑器主界面，并记录版本变更以触发更新提示。
 */
public class Welcome extends Activity {

    private static final String PREFS_NAME = "mini_luaxplus_startup";
    private static final String KEY_LAST_VERSION = "last_version";
    private static final long SPLASH_DELAY_MS = 500L;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(createSplashView());
        new Handler(Looper.getMainLooper()).postDelayed(new Runnable() {
            @Override
            public void run() {
                startEditor();
            }
        }, SPLASH_DELAY_MS);
    }

    private View createSplashView() {
        int padding = dp(24);

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setGravity(Gravity.CENTER);
        root.setBackgroundColor(resolveThemeColor(android.R.attr.colorBackground));
        root.setPadding(padding, padding, padding, padding);

        ImageView logo = new ImageView(this);
        logo.setImageResource(R.mipmap.ic_launcher);
        int logoSize = dp(112);
        root.addView(logo, new LinearLayout.LayoutParams(logoSize, logoSize));

        TextView title = new TextView(this);
        title.setText("Mini-LuaXPLUS");
        title.setTextSize(TypedValue.COMPLEX_UNIT_SP, 22);
        title.setTypeface(title.getTypeface(), android.graphics.Typeface.BOLD);
        title.setTextColor(resolveThemeColor(android.R.attr.textColorPrimary));
        title.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams titleParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        titleParams.topMargin = dp(20);
        root.addView(title, titleParams);

        TextView tagline = new TextView(this);
        tagline.setText("在手机上用 Lua 写应用");
        tagline.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        tagline.setTextColor(resolveThemeColor(android.R.attr.textColorSecondary));
        tagline.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams taglineParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        taglineParams.topMargin = dp(8);
        root.addView(tagline, taglineParams);

        return root;
    }

    private void startEditor() {
        if (isFinishing()) {
            return;
        }
        Intent intent = new Intent(this, Main.class);
        String currentVersion = readVersionName();
        SharedPreferences preferences = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        String lastVersion = preferences.getString(KEY_LAST_VERSION, "");
        if (!currentVersion.equals(lastVersion)) {
            intent.putExtra("isVersionChanged", true);
            intent.putExtra("newVersionName", currentVersion);
            intent.putExtra("oldVersionName", lastVersion);
            preferences.edit().putString(KEY_LAST_VERSION, currentVersion).apply();
        }
        startActivity(intent);
        finish();
    }

    private String readVersionName() {
        try {
            return getPackageManager().getPackageInfo(getPackageName(), 0).versionName;
        } catch (Exception e) {
            return "";
        }
    }

    private int resolveThemeColor(int attribute) {
        TypedValue value = new TypedValue();
        if (getTheme().resolveAttribute(attribute, value, true)) {
            if (value.resourceId != 0) {
                return getResources().getColor(value.resourceId);
            }
            return value.data;
        }
        return 0;
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }
}
