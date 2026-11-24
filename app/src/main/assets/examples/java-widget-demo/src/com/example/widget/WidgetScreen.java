package com.example.widget;

import android.graphics.Color;
import android.text.InputType;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.SeekBar;
import android.widget.Switch;
import android.widget.TextView;

import com.mini.luaxplus.java.JavaHost;
import com.mini.luaxplus.java.JavaScreen;

/** 纯 Java 控件页：输入框、滑杆、开关和按钮都不依赖 Lua。 */
public class WidgetScreen implements JavaScreen {

    private JavaHost host;

    @Override
    public void onCreate(JavaHost host) {
        this.host = host;
        host.setScreenTitle("Java 控件");
    }

    @Override
    public View onCreateView(final JavaHost host) {
        final LinearLayout root = new LinearLayout(host.context());
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(host, 20), dp(host, 24), dp(host, 20), dp(host, 20));
        root.setBackgroundColor(Color.rgb(249, 250, 252));

        TextView title = new TextView(host.context());
        title.setText("Java 控件实验");
        title.setTextSize(24);
        title.setTextColor(Color.rgb(20, 24, 33));
        root.addView(title);

        final EditText input = new EditText(host.context());
        input.setHint("输入一段文字");
        input.setSingleLine(true);
        input.setInputType(InputType.TYPE_CLASS_TEXT);
        LinearLayout.LayoutParams inputParams = new LinearLayout.LayoutParams(-1, -2);
        inputParams.topMargin = dp(host, 18);
        root.addView(input, inputParams);

        final TextView volumeLabel = new TextView(host.context());
        volumeLabel.setText("音量：40");
        volumeLabel.setTextSize(15);
        volumeLabel.setTextColor(Color.rgb(84, 92, 108));
        LinearLayout.LayoutParams labelParams = new LinearLayout.LayoutParams(-1, -2);
        labelParams.topMargin = dp(host, 16);
        root.addView(volumeLabel, labelParams);

        SeekBar seekBar = new SeekBar(host.context());
        seekBar.setMax(100);
        seekBar.setProgress(40);
        seekBar.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar bar, int progress, boolean fromUser) {
                volumeLabel.setText("音量：" + progress);
            }

            @Override
            public void onStartTrackingTouch(SeekBar bar) {
            }

            @Override
            public void onStopTrackingTouch(SeekBar bar) {
            }
        });
        root.addView(seekBar, new LinearLayout.LayoutParams(-1, -2));

        final Switch toggle = new Switch(host.context());
        toggle.setText("深色背景");
        LinearLayout.LayoutParams toggleParams = new LinearLayout.LayoutParams(-1, -2);
        toggleParams.topMargin = dp(host, 10);
        root.addView(toggle, toggleParams);

        final TextView result = new TextView(host.context());
        result.setText("等待操作");
        result.setTextSize(14);
        result.setTextColor(Color.rgb(72, 80, 96));
        result.setGravity(Gravity.START);
        LinearLayout.LayoutParams resultParams = new LinearLayout.LayoutParams(-1, -2);
        resultParams.topMargin = dp(host, 18);
        root.addView(result, resultParams);

        Button apply = new Button(host.context());
        apply.setText("应用输入");
        apply.setAllCaps(false);
        apply.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                String text = input.getText().toString().trim();
                result.setText(text.isEmpty() ? "输入为空" : "Java 读到：" + text);
            }
        });
        LinearLayout.LayoutParams applyParams = new LinearLayout.LayoutParams(-1, dp(host, 48));
        applyParams.topMargin = dp(host, 16);
        root.addView(apply, applyParams);

        toggle.setOnCheckedChangeListener(new android.widget.CompoundButton.OnCheckedChangeListener() {
            @Override
            public void onCheckedChanged(android.widget.CompoundButton buttonView, boolean isChecked) {
                root.setBackgroundColor(isChecked ? Color.rgb(28, 32, 40) : Color.rgb(249, 250, 252));
                title.setTextColor(isChecked ? Color.WHITE : Color.rgb(20, 24, 33));
                result.setTextColor(isChecked ? Color.rgb(220, 226, 236) : Color.rgb(72, 80, 96));
                result.setText(isChecked ? "已切换深色背景" : "已切换浅色背景");
            }
        });
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
