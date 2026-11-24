package com.mini.luaxplus.java;

import android.app.Activity;
import android.content.Context;
import android.content.res.Resources;
import android.graphics.Color;
import android.os.Bundle;
import android.text.method.ScrollingMovementMethod;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.luajava.LuaState;
import com.mini.luaxplus.LogCore;

/** 预注册的 Java 页面宿主。动态 DEX 中的页面通过它获得 Activity 能力。 */
public class JavaHostActivity extends Activity implements JavaHost {

    private JavaScreen screen;
    private LuaBridge bridge;
    private String luaToken;
    private String projectDir;
    private String dexPath;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        luaToken = getIntent().getStringExtra(JavaRuntime.EXTRA_LUA_TOKEN);
        projectDir = getIntent().getStringExtra(JavaRuntime.EXTRA_PROJECT_DIR);
        dexPath = getIntent().getStringExtra(JavaRuntime.EXTRA_DEX_PATH);
        String screenClass = getIntent().getStringExtra(JavaRuntime.EXTRA_SCREEN);
        if (screenClass == null || screenClass.trim().isEmpty()) {
            showError("没有指定 Java 页面类", null);
            return;
        }
        try {
            LuaState state = LuaStateRegistry.get(luaToken);
            if (state != null) {
                bridge = new LuaBridge(state);
            }
            Class<?> target = loadScreenClass(screenClass);
            Object instance = target.newInstance();
            if (!(instance instanceof JavaScreen)) {
                throw new IllegalArgumentException(screenClass + " 必须实现 JavaScreen");
            }
            screen = (JavaScreen) instance;
            screen.onCreate(this);
            View content = screen.onCreateView(this);
            if (content == null) {
                throw new IllegalStateException(screenClass + " 返回了空 View");
            }
            setContentView(content);
        } catch (Throwable error) {
            showError("Java 页面加载失败: " + screenClass, error);
        }
    }

    private Class<?> loadScreenClass(String name) throws ClassNotFoundException, java.io.IOException {
        try {
            return Class.forName(name, true, getClassLoader());
        } catch (ClassNotFoundException notInApk) {
            ClassLoader dexLoader;
            if (dexPath != null && !dexPath.trim().isEmpty()) {
                dexLoader = JavaDexLoader.fromPath(this, dexPath);
            } else {
                dexLoader = JavaDexLoader.load(this);
            }
            if (dexLoader == null) {
                throw notInApk;
            }
            return Class.forName(name, true, dexLoader);
        }
    }

    private void showError(String message, Throwable error) {
        if (error != null) {
            LogCore.javaError(message, error);
        }
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(24), dp(24), dp(24), dp(24));
        root.setBackgroundColor(Color.WHITE);

        TextView title = new TextView(this);
        title.setText(message);
        title.setTextSize(TypedValue.COMPLEX_UNIT_SP, 18);
        title.setTextColor(Color.rgb(180, 30, 30));
        root.addView(title, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        TextView detail = new TextView(this);
        detail.setText(error == null ? "请检查启动参数" : android.util.Log.getStackTraceString(error));
        detail.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        detail.setTextColor(Color.rgb(40, 40, 40));
        detail.setMovementMethod(new ScrollingMovementMethod());
        LinearLayout.LayoutParams detailParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f);
        detailParams.topMargin = dp(12);
        root.addView(detail, detailParams);

        Button close = new Button(this);
        close.setText("关闭");
        close.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                finish();
            }
        });
        LinearLayout.LayoutParams closeParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        closeParams.gravity = Gravity.END;
        closeParams.topMargin = dp(12);
        root.addView(close, closeParams);
        setContentView(root);
    }

    private int dp(int value) {
        return (int) (value * getResources().getDisplayMetrics().density + 0.5f);
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (screen != null) {
            try {
                screen.onResume(this);
            } catch (Throwable error) {
                showError("Java 页面 onResume 失败", error);
            }
        }
    }

    @Override
    protected void onPause() {
        if (screen != null) {
            try {
                screen.onPause(this);
            } catch (Throwable error) {
                showError("Java 页面 onPause 失败", error);
            }
        }
        super.onPause();
    }

    @Override
    protected void onDestroy() {
        if (screen != null) {
            try {
                screen.onDestroy(this);
            } catch (Throwable ignored) {
                // 页面已销毁，清理异常不再覆盖用户正在看的错误页
            }
        }
        if (luaToken != null) {
            LuaStateRegistry.release(luaToken);
        }
        super.onDestroy();
    }

    @Override
    public void onBackPressed() {
        if (screen != null && screen.onBackPressed(this)) {
            return;
        }
        super.onBackPressed();
    }

    @Override
    public Activity activity() {
        return this;
    }

    @Override
    public Context context() {
        return this;
    }

    @Override
    public Resources resources() {
        return getResources();
    }

    @Override
    public String projectDir() {
        return projectDir;
    }

    @Override
    public LuaBridge lua() {
        return bridge;
    }

    @Override
    public String argument(String key) {
        if (key == null) {
            return null;
        }
        String direct = getIntent().getStringExtra(key);
        if (direct != null) {
            return direct;
        }
        return getIntent().getStringExtra(JavaRuntime.EXTRA_ARGUMENT);
    }

    @Override
    public void setScreenTitle(final String title) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                setTitle(title);
            }
        });
    }
}
