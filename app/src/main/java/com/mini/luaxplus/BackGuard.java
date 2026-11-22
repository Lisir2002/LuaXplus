package com.mini.luaxplus;

import android.app.Activity;

import androidx.activity.ComponentActivity;
import androidx.activity.OnBackPressedCallback;

/**
 * 返回键守卫：统一接管系统返回与手势返回，交给脚本决定是否退出。
 * 脚本通过 setHandler 注入处理函数，未注入时按默认行为退出。
 */
public final class BackGuard {

    private static Runnable handler;
    private static OnBackPressedCallback callback;

    private BackGuard() {
    }

    public static void install(final Activity activity) {
        if (!(activity instanceof ComponentActivity)) {
            return;
        }
        handler = null;
        callback = new OnBackPressedCallback(true) {
            @Override
            public void handleOnBackPressed() {
                Runnable current = handler;
                if (current != null) {
                    current.run();
                } else {
                    setEnabled(false);
                    activity.onBackPressed();
                }
            }
        };
        ((ComponentActivity) activity).getOnBackPressedDispatcher().addCallback(callback);
    }

    public static void setHandler(Runnable runnable) {
        handler = runnable;
    }

    public static void clear() {
        handler = null;
        callback = null;
    }
}
