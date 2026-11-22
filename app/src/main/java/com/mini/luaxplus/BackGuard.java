package com.mini.luaxplus;

import android.app.Activity;

import androidx.activity.ComponentActivity;
import androidx.activity.OnBackPressedCallback;

import java.util.Map;
import java.util.WeakHashMap;

/**
 * 返回键守卫：统一接管系统返回与手势返回，交给脚本决定是否退出。
 * 处理函数按页面实例保存，避免多个页面共用同一份导致串页。
 */
public final class BackGuard {

    private static final Map<Activity, Runnable> HANDLERS = new WeakHashMap<>();

    private BackGuard() {
    }

    public static void install(final Activity activity) {
        if (!(activity instanceof ComponentActivity)) {
            return;
        }
        synchronized (HANDLERS) {
            HANDLERS.remove(activity);
        }
        OnBackPressedCallback callback = new OnBackPressedCallback(true) {
            @Override
            public void handleOnBackPressed() {
                Runnable handler;
                synchronized (HANDLERS) {
                    handler = HANDLERS.get(activity);
                }
                if (handler != null) {
                    handler.run();
                } else {
                    setEnabled(false);
                    activity.onBackPressed();
                }
            }
        };
        ((ComponentActivity) activity).getOnBackPressedDispatcher().addCallback(callback);
    }

    public static void setHandler(Activity activity, Runnable runnable) {
        synchronized (HANDLERS) {
            HANDLERS.put(activity, runnable);
        }
    }

    public static void clear(Activity activity) {
        synchronized (HANDLERS) {
            HANDLERS.remove(activity);
        }
    }
}
