package com.mini.luaxplus;

import android.app.Activity;
import android.app.Application;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;

/**
 * 运行时观察者：接管未捕获异常并记录页面生命周期，覆盖崩溃与操作轨迹。
 */
public final class RuntimeWatcher {

    private static final String TAG = "Watcher";
    private static boolean installed;

    private RuntimeWatcher() {
    }

    public static void install(Context context) {
        if (installed || context == null) {
            return;
        }
        installed = true;
        installCrashHandler();
        installLifecycle(context);
        LogCore.i(TAG, "运行监控已启用");
    }

    /** 记录 Java 层未捕获异常，再交回系统原有处理流程 */
    private static void installCrashHandler() {
        final Thread.UncaughtExceptionHandler previous = Thread.getDefaultUncaughtExceptionHandler();
        Thread.setDefaultUncaughtExceptionHandler(new Thread.UncaughtExceptionHandler() {
            @Override
            public void uncaughtException(Thread thread, Throwable throwable) {
                try {
                    LogCore.crash(throwable, thread);
                } catch (Throwable ignored) {
                    // 崩溃记录失败不能再抛异常，避免掩盖原始崩溃
                }
                if (previous != null) {
                    previous.uncaughtException(thread, throwable);
                }
            }
        });
    }

    /** 记录页面生命周期与跳转来源 */
    private static void installLifecycle(Context context) {
        Context applicationContext = context.getApplicationContext();
        if (!(applicationContext instanceof Application)) {
            return;
        }
        ((Application) applicationContext).registerActivityLifecycleCallbacks(
                new Application.ActivityLifecycleCallbacks() {
                    @Override
                    public void onActivityCreated(Activity activity, Bundle savedInstanceState) {
                        LogCore.i(TAG, "创建 " + name(activity) + describe(getIntent(activity)));
                    }

                    @Override
                    public void onActivityStarted(Activity activity) {
                        LogCore.d(TAG, "显示 " + name(activity));
                    }

                    @Override
                    public void onActivityResumed(Activity activity) {
                        LogCore.d(TAG, "前台 " + name(activity));
                    }

                    @Override
                    public void onActivityPaused(Activity activity) {
                        LogCore.d(TAG, "暂停 " + name(activity));
                    }

                    @Override
                    public void onActivityStopped(Activity activity) {
                        LogCore.d(TAG, "后台 " + name(activity));
                    }

                    @Override
                    public void onActivitySaveInstanceState(Activity activity, Bundle outState) {
                        LogCore.d(TAG, "保存状态 " + name(activity));
                    }

                    @Override
                    public void onActivityDestroyed(Activity activity) {
                        LogCore.i(TAG, "销毁 " + name(activity));
                    }
                });
    }

    private static Intent getIntent(Activity activity) {
        try {
            return activity.getIntent();
        } catch (Exception exception) {
            return null;
        }
    }

    private static String name(Activity activity) {
        return activity == null ? "unknown" : activity.getClass().getName();
    }

    private static String describe(Intent intent) {
        if (intent == null) {
            return " intent=无";
        }
        StringBuilder builder = new StringBuilder(" action=");
        builder.append(intent.getAction());
        if (intent.getData() != null) {
            builder.append(" data=").append(intent.getData());
        }
        return builder.toString();
    }
}
