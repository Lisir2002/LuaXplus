package com.mini.luaxplus;

import android.app.Activity;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.os.SystemClock;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.androlua.Main;

/**
 * 品牌启动页：初始化日志与运行监控，铺设运行时脚本后进入编辑器主界面，
 * 并记录版本变更以触发更新提示。
 */
public class Welcome extends Activity {

    private static final String PREFS_NAME = "mini_luaxplus_startup";
    private static final String KEY_LAST_VERSION = "last_version";
    private static final long SPLASH_DELAY_MS = 500L;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        LogCore.init(this);
        RuntimeWatcher.install(this);
        if (!LogCore.OWNER_PACKAGE.equals(getPackageName())) {
            // 成品包不再抢在首屏之前弹权限页，等应用界面显示后再申请
            LaunchPermissions.arm(getApplication());
        }
        LogCore.i("Welcome", "启动页创建 version=" + readVersionName()
                + " 日志目录=" + LogCore.dir());
        setContentView(createSplashView());
        prepareAndStartEditor();
    }

    private void prepareAndStartEditor() {
        final long startedAt = SystemClock.elapsedRealtime();
        new Thread(new Runnable() {
            @Override
            public void run() {
                boolean ready = AssetBootstrap.ensure(Welcome.this);
                long cost = SystemClock.elapsedRealtime() - startedAt;
                LogCore.i("Welcome", "脚本准备结果=" + ready + " 耗时=" + cost + "ms");
                long remain = SPLASH_DELAY_MS - cost;
                if (remain > 0) {
                    SystemClock.sleep(remain);
                }
                runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        startEditor();
                    }
                });
            }
        }, "luaxplus-bootstrap").start();
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
        title.setText(getApplicationInfo().loadLabel(getPackageManager()));
        title.setTextSize(TypedValue.COMPLEX_UNIT_SP, 22);
        title.setTypeface(title.getTypeface(), android.graphics.Typeface.BOLD);
        title.setTextColor(resolveThemeColor(android.R.attr.textColorPrimary));
        title.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams titleParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        titleParams.topMargin = dp(20);
        root.addView(title, titleParams);

        TextView tagline = new TextView(this);
        tagline.setText(LogCore.OWNER_PACKAGE.equals(getPackageName())
                ? "在手机上用 Lua 写应用"
                : "正在启动…");
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
            LogCore.w("Welcome", "页面已结束，跳过进入编辑器");
            return;
        }
        Intent intent = new Intent(this, Main.class);
        String currentVersion = readVersionName();
        SharedPreferences preferences = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        String lastVersion = preferences.getString(KEY_LAST_VERSION, "");
        LogCore.i("Welcome", "进入编辑器 当前=" + currentVersion + " 上次=" + lastVersion);
        if (!currentVersion.equals(lastVersion)) {
            intent.putExtra("isVersionChanged", true);
            intent.putExtra("newVersionName", currentVersion);
            intent.putExtra("oldVersionName", lastVersion);
            preferences.edit().putString(KEY_LAST_VERSION, currentVersion).apply();
            LogCore.i("Welcome", "标记版本变更提示 " + lastVersion + " -> " + currentVersion);
        }
        try {
            startActivity(intent);
        } catch (Exception exception) {
            LogCore.crash(exception, Thread.currentThread());
            throw new RuntimeException("打开编辑器失败", exception);
        }
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
