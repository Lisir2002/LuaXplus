package com.mini.luaxplus.java.demo;

import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.mini.luaxplus.java.JavaHost;
import com.mini.luaxplus.java.JavaScreen;

/** 宿主页面的最小示例：完全用 Java 创建界面，并可回调 Lua。 */
public class HelloScreen implements JavaScreen {

    private JavaHost host;

    @Override
    public void onCreate(JavaHost host) {
        this.host = host;
        host.setScreenTitle("Java 页面");
    }

    @Override
    public View onCreateView(final JavaHost host) {
        int padding = dp(24);

        LinearLayout root = new LinearLayout(host.context());
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(padding, padding, padding, padding);
        root.setBackgroundColor(Color.rgb(248, 249, 252));

        TextView title = new TextView(host.context());
        title.setText("Java 页面已运行");
        title.setTextSize(24);
        title.setTextColor(Color.rgb(24, 28, 36));
        title.setGravity(Gravity.START);
        root.addView(title, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        TextView detail = new TextView(host.context());
        detail.setText("这个界面由 Java 代码创建，没有 Lua 参与布局。\n"
                + "宿主 Activity 已预注册，动态 DEX 中的页面也可以复用同一套生命周期。\n"
                + "设备: " + Build.MANUFACTURER + " " + Build.MODEL);
        detail.setTextSize(15);
        detail.setTextColor(Color.rgb(84, 92, 108));
        detail.setLineSpacing(dp(4), 1f);
        LinearLayout.LayoutParams detailParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        detailParams.topMargin = dp(16);
        root.addView(detail, detailParams);

        Button callback = new Button(host.context());
        callback.setText("回调 Lua（如果已挂载）");
        callback.setAllCaps(false);
        GradientDrawable background = new GradientDrawable();
        background.setColor(Color.rgb(44, 98, 238));
        background.setCornerRadius(dp(10));
        callback.setBackground(background);
        callback.setTextColor(Color.WHITE);
        callback.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if (host.lua() == null) {
                    detail.setText("当前是独立 Java 启动，没有挂载 LuaState。\n"
                            + "从 Lua 打开时会自动建立双向桥。");
                    return;
                }
                detail.setText("已向 Lua 发送 onJavaPageEvent。");
                host.lua().post("onJavaPageEvent", "hello-from-java");
            }
        });
        LinearLayout.LayoutParams buttonParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(48));
        buttonParams.topMargin = dp(24);
        root.addView(callback, buttonParams);
        return root;
    }

    private int dp(int value) {
        return (int) (value * host.resources().getDisplayMetrics().density + 0.5f);
    }
}
