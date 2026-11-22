package com.mini.luaxplus;

import android.app.Activity;
import android.app.Application;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import java.util.Map;
import java.util.WeakHashMap;

/**
 * 运行时观察者：接管未捕获异常并记录页面生命周期，覆盖崩溃与操作轨迹。
 */
public final class RuntimeWatcher {

    private static final String TAG = "Watcher";
    private static boolean installed;
    /** 已记录过的错误页文本，按页面实例隔离，避免重复快照 */
    private static final Map<Object, String> SEEN_ERROR = new WeakHashMap<>();

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
                        snapshotErrorScreen(activity);
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
                        synchronized (SEEN_ERROR) {
                            SEEN_ERROR.remove(activity);
                        }
                    }
                });
    }


    /** 兜底：页面上出现任何错误文本（含语法错误）都截取整页文字存快照 */
    private static void snapshotErrorScreen(Activity activity) {
        try {
            View root = activity.getWindow().getDecorView();
            String text = collectErrorText(root);
            if (text == null) {
                return;
            }
            synchronized (SEEN_ERROR) {
                String previous = SEEN_ERROR.get(activity);
                if (text.equals(previous)) {
                    return;
                }
                SEEN_ERROR.put(activity, text);
            }
            LogCore.luaError("界面错误 " + activity.getClass().getName(), text);
        } catch (Throwable ignored) {
            // 截屏兜底失败不能影响页面
        }
    }

    /** 收集整棵视图树的文字，命中错误特征时返回整段内容 */
    private static String collectErrorText(View view) {
        StringBuilder builder = new StringBuilder();
        collect(view, builder);
        String text = builder.toString().trim();
        if (text.isEmpty()) {
            return null;
        }
        if (text.contains("Syntax error") || text.contains("Runtime error")
                || text.contains("stack traceback") || text.contains("LuaException")
                || text.contains("Invalid method call") || text.contains("is not a field")
                || text.contains("attempt to ") || text.contains("module '")
                || text.startsWith("error")) {
            if (text.length() > 6000) {
                return text.substring(0, 6000) + "\n…（内容过长已截断）";
            }
            return text;
        }
        return null;
    }

    private static void collect(View view, StringBuilder builder) {
        if (view == null) {
            return;
        }
        if (view instanceof TextView) {
            CharSequence content = ((TextView) view).getText();
            if (content != null && content.length() > 0) {
                builder.append(content).append('\n');
            }
        }
        if (view instanceof ViewGroup) {
            ViewGroup group = (ViewGroup) view;
            for (int index = 0; index < group.getChildCount(); index++) {
                collect(group.getChildAt(index), builder);
            }
        }
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
