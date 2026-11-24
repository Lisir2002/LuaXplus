package com.example.bridge;

import android.graphics.Color;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.mini.luaxplus.java.JavaHost;
import com.mini.luaxplus.java.JavaScreen;

/** 双向调用示例：Lua 传参数给 Java，Java 回调 Lua，再把 Lua 返回值显示出来。 */
public class BridgeScreen implements JavaScreen {

    private JavaHost host;
    private TextView status;

    @Override
    public void onCreate(JavaHost host) {
        this.host = host;
        host.setScreenTitle("Lua ↔ Java");
    }

    @Override
    public View onCreateView(final JavaHost host) {
        LinearLayout root = new LinearLayout(host.context());
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(host, 24), dp(host, 32), dp(host, 24), dp(host, 24));
        root.setBackgroundColor(Color.rgb(246, 248, 252));

        TextView title = new TextView(host.context());
        title.setText("Lua ↔ Java");
        title.setTextSize(28);
        title.setTextColor(Color.rgb(18, 24, 36));
        root.addView(title);

        TextView argument = new TextView(host.context());
        String message = host.argument("message");
        argument.setText("Lua 传入的参数：\n" + (message == null ? "（没有参数）" : message));
        argument.setTextSize(15);
        argument.setTextColor(Color.rgb(76, 86, 102));
        argument.setLineSpacing(dp(host, 4), 1f);
        LinearLayout.LayoutParams argumentParams = new LinearLayout.LayoutParams(-1, -2);
        argumentParams.topMargin = dp(host, 18);
        root.addView(argument, argumentParams);

        TextView luaValue = new TextView(host.context());
        luaValue.setText("Java 读取 Lua：" + readLuaMessage(host));
        luaValue.setTextSize(14);
        luaValue.setTextColor(Color.rgb(44, 98, 238));
        LinearLayout.LayoutParams luaParams = new LinearLayout.LayoutParams(-1, -2);
        luaParams.topMargin = dp(host, 14);
        root.addView(luaValue, luaParams);

        status = new TextView(host.context());
        status.setText("点击按钮，让 Java 调用 Lua 的 onJavaMessage。");
        status.setTextSize(14);
        status.setTextColor(Color.rgb(70, 78, 92));
        LinearLayout.LayoutParams statusParams = new LinearLayout.LayoutParams(-1, -2);
        statusParams.topMargin = dp(host, 22);
        root.addView(status, statusParams);

        Button callLua = new Button(host.context());
        callLua.setText("Java 调用 Lua");
        callLua.setAllCaps(false);
        callLua.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if (host.lua() == null) {
                    status.setText("没有 LuaState，当前是纯 Java 模式");
                    return;
                }
                try {
                    Object result = host.lua().call("onJavaMessage", "来自 BridgeScreen");
                    status.setText("Java → Lua 已调用\nLua 返回：" + String.valueOf(result));
                } catch (Throwable error) {
                    status.setText("Java → Lua 失败：" + error.getMessage());
                }
            }
        });
        LinearLayout.LayoutParams buttonParams = new LinearLayout.LayoutParams(-1, dp(host, 48));
        buttonParams.topMargin = dp(host, 12);
        root.addView(callLua, buttonParams);

        TextView footer = new TextView(host.context());
        footer.setText("Lua → Java 通过动态静态方法调用；Java → Lua 通过 LuaBridge.call。");
        footer.setTextSize(12);
        footer.setTextColor(Color.rgb(132, 140, 154));
        footer.setGravity(Gravity.END);
        LinearLayout.LayoutParams footerParams = new LinearLayout.LayoutParams(-1, -2);
        footerParams.topMargin = dp(host, 20);
        root.addView(footer, footerParams);
        return root;
    }

    private String readLuaMessage(JavaHost host) {
        if (host.lua() == null) {
            return "无 LuaState";
        }
        try {
            Object value = host.lua().call("getLuaMessage");
            return value == null ? "Lua 没有返回值" : String.valueOf(value);
        } catch (Throwable error) {
            return "读取失败：" + error.getMessage();
        }
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
