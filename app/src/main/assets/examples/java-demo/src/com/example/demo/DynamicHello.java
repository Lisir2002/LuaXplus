package com.example.demo;

import android.graphics.Color;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.mini.luaxplus.java.JavaHost;
import com.mini.luaxplus.java.JavaScreen;

/** 由手机内 ECJ + D8 编译的示例页面，用来验证动态 DEX 和宿主生命周期。 */
public class DynamicHello implements JavaScreen {

    private JavaHost host;

    @Override
    public void onCreate(JavaHost host) {
        this.host = host;
        host.setScreenTitle("动态 Java 页面");
    }

    @Override
    public View onCreateView(final JavaHost host) {
        LinearLayout root = new LinearLayout(host.context());
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(host, 24), dp(host, 24), dp(host, 24), dp(host, 24));
        root.setBackgroundColor(Color.rgb(245, 247, 251));

        TextView title = new TextView(host.context());
        title.setText("动态 DEX 已加载");
        title.setTextSize(23);
        title.setTextColor(Color.rgb(20, 24, 33));
        root.addView(title, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        TextView body = new TextView(host.context());
        body.setText("这个页面的 .java 在手机上被编译成 .class，再由 D8 转成 classes.dex，"
                + "最后由 JavaHostActivity 通过 DexClassLoader 加载。");
        body.setTextSize(15);
        body.setTextColor(Color.rgb(82, 90, 105));
        body.setLineSpacing(dp(host, 5), 1f);
        LinearLayout.LayoutParams bodyParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        bodyParams.topMargin = dp(host, 14);
        root.addView(body, bodyParams);

        Button button = new Button(host.context());
        button.setText("回调 Lua");
        button.setAllCaps(false);
        button.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if (host.lua() != null) {
                    host.lua().post("onJavaPageEvent", "dynamic-dex");
                }
            }
        });
        LinearLayout.LayoutParams buttonParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(host, 46));
        buttonParams.topMargin = dp(host, 22);
        root.addView(button, buttonParams);

        TextView footer = new TextView(host.context());
        footer.setText("编译产物: classes.dex");
        footer.setTextSize(12);
        footer.setTextColor(Color.rgb(128, 136, 150));
        footer.setGravity(Gravity.END);
        LinearLayout.LayoutParams footerParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        footerParams.topMargin = dp(host, 16);
        root.addView(footer, footerParams);
        return root;
    }

    private int dp(JavaHost host, int value) {
        return (int) (value * host.resources().getDisplayMetrics().density + 0.5f);
    }

    @Override
    public void onResume(JavaHost host) {
    }

    @Override
    public void onPause(JavaHost host) {
    }

    @Override
    public void onDestroy(JavaHost host) {
    }

    @Override
    public boolean onBackPressed(JavaHost host) {
        return false;
    }
}
