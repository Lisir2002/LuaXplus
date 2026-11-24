package com.example.pure;

import android.graphics.Color;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.mini.luaxplus.java.JavaHost;
import com.mini.luaxplus.java.JavaScreen;

/** 纯 Java 页面：不读取 LuaState，也不调用 Lua。 */
public class PureScreen implements JavaScreen {

    private JavaHost host;
    private int taps;

    @Override
    public void onCreate(JavaHost host) {
        this.host = host;
        host.setScreenTitle("纯 Java 页面");
    }

    @Override
    public View onCreateView(final JavaHost host) {
        LinearLayout root = new LinearLayout(host.context());
        root.setOrientation(LinearLayout.VERTICAL);
        root.setGravity(Gravity.CENTER_HORIZONTAL);
        root.setPadding(dp(host, 24), dp(host, 40), dp(host, 24), dp(host, 24));
        root.setBackgroundColor(Color.rgb(247, 249, 253));

        TextView title = new TextView(host.context());
        title.setText("Pure Java");
        title.setTextSize(30);
        title.setTextColor(Color.rgb(18, 24, 36));
        title.setGravity(Gravity.CENTER);
        root.addView(title, new LinearLayout.LayoutParams(-1, -2));

        TextView note = new TextView(host.context());
        note.setText("这个页面完全由 Java 创建，启动时没有挂载 LuaState。\n"
                + "按钮、布局、状态和生命周期都走 JavaHost 的宿主 Activity。");
        note.setTextSize(15);
        note.setTextColor(Color.rgb(84, 92, 108));
        note.setGravity(Gravity.CENTER);
        note.setLineSpacing(dp(host, 5), 1f);
        LinearLayout.LayoutParams noteParams = new LinearLayout.LayoutParams(-1, -2);
        noteParams.topMargin = dp(host, 18);
        root.addView(note, noteParams);

        final TextView counter = new TextView(host.context());
        counter.setText("点击次数：0");
        counter.setTextSize(20);
        counter.setTextColor(Color.rgb(44, 98, 238));
        counter.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams counterParams = new LinearLayout.LayoutParams(-1, -2);
        counterParams.topMargin = dp(host, 36);
        root.addView(counter, counterParams);

        Button button = new Button(host.context());
        button.setText("点一下");
        button.setAllCaps(false);
        button.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                taps++;
                counter.setText("点击次数：" + taps);
            }
        });
        LinearLayout.LayoutParams buttonParams = new LinearLayout.LayoutParams(-1, dp(host, 48));
        buttonParams.topMargin = dp(host, 18);
        root.addView(button, buttonParams);

        TextView footer = new TextView(host.context());
        footer.setText("Lua 桥：未挂载");
        footer.setTextSize(12);
        footer.setTextColor(Color.rgb(130, 138, 152));
        footer.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams footerParams = new LinearLayout.LayoutParams(-1, -2);
        footerParams.topMargin = dp(host, 30);
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
