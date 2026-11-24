package com.mini.luaxplus;

import android.app.Activity;
import android.app.Application;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
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
    private static boolean crashHandlerInstalled;
    private static Thread.UncaughtExceptionHandler ownHandler;
    private static Context appContext;
    /** 已记录过的错误页文本，按页面实例隔离，避免重复快照 */
    private static final Map<Object, String> SEEN_ERROR = new WeakHashMap<>();
    /** 错误页内容会分批写入，先缓存再统一落盘，避免只截到标题 */
    private static final Map<Object, String> PENDING = new WeakHashMap<>();
    private static final Handler MAIN = new Handler(Looper.getMainLooper());
    /** 页面稳定前多次抓取，最后一次再写快照 */
    private static final long[] CAPTURE_DELAYS = {250L, 1000L, 2500L};

    private RuntimeWatcher() {
    }

    public static void install(Context context) {
        if (installed || context == null) {
            return;
        }
        installed = true;
        setContext(context);
        BootTrace.mark("RuntimeWatcher.install begin");
        installCrashHandler();
        BootTrace.mark("RuntimeWatcher.install handler ready");
        installLifecycle(context);
        BootTrace.mark("RuntimeWatcher.install lifecycle ready");
        LogCore.i(TAG, "运行监控已启用");
    }

    /** Application 或 ContentProvider 最早阶段没有完整初始化，先交入上下文供崩溃快照使用 */
    public static void setContext(Context context) {
        if (context == null) {
            return;
        }
        Context applicationContext = context.getApplicationContext();
        appContext = applicationContext == null ? context : applicationContext;
    }

    /** 记录 Java 层未捕获异常，再交回系统原有处理流程；可在 Application 之前调用 */
    public static void installCrashHandler() {
        installCrashHandler(false);
    }

    /** 父类初始化可能替换默认处理器，启动完成后强制重新接管并保留当前处理器 */
    public static void refreshCrashHandler() {
        BootTrace.mark("RuntimeWatcher.refreshCrashHandler begin");
        installCrashHandler(true);
        BootTrace.mark("RuntimeWatcher.refreshCrashHandler done");
    }

    private static void installCrashHandler(boolean force) {
        if (crashHandlerInstalled && !force) {
            return;
        }
        crashHandlerInstalled = true;
        final Thread.UncaughtExceptionHandler previous = Thread.getDefaultUncaughtExceptionHandler();
        if (previous == ownHandler) {
            return;
        }
        Thread.UncaughtExceptionHandler handler = new Thread.UncaughtExceptionHandler() {
            @Override
            public void uncaughtException(Thread thread, Throwable throwable) {
                try {
                    BootTrace.crash(throwable, thread);
                } catch (Throwable ignored) {
                }
                try {
                    LogCore.crash(throwable, thread);
                } catch (Throwable ignored) {
                    // 崩溃记录失败不能再抛异常，避免掩盖原始崩溃
                }
                try {
                    LogInjection.recordCrash(appContext, throwable);
                } catch (Throwable ignored) {
                    // 崩溃报告只做辅助，不能影响系统原有处理
                }
                if (previous != null) {
                    previous.uncaughtException(thread, throwable);
                }
            }
        };
        ownHandler = handler;
        Thread.setDefaultUncaughtExceptionHandler(handler);
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
                        RuntimeWatcher.refreshCrashHandler();
                        BootTrace.mark("Activity created " + activity.getClass().getName());
                        LogCore.i(TAG, "创建 " + name(activity) + describe(getIntent(activity)));
                    }

                    @Override
                    public void onActivityStarted(Activity activity) {
                        RuntimeWatcher.refreshCrashHandler();
                        BootTrace.mark("Activity started " + activity.getClass().getName());
                        LogCore.d(TAG, "显示 " + name(activity));
                    }

                    @Override
                    public void onActivityResumed(Activity activity) {
                        RuntimeWatcher.refreshCrashHandler();
                        BootTrace.mark("Activity resumed " + activity.getClass().getName());
                        LogCore.d(TAG, "前台 " + name(activity));
                        scheduleCapture(activity);
                    }

                    @Override
                    public void onActivityPaused(Activity activity) {
                        LogCore.d(TAG, "暂停 " + name(activity));
                        flushSnapshot(activity);
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
                        flushSnapshot(activity);
                        synchronized (SEEN_ERROR) {
                            SEEN_ERROR.remove(activity);
                        }
                    }
                });
    }


    /** 兜底：页面上出现任何错误文本（含语法错误）都截取整页文字存快照 */
    private static void scheduleCapture(final Activity activity) {
        for (int index = 0; index < CAPTURE_DELAYS.length; index++) {
            final boolean last = index == CAPTURE_DELAYS.length - 1;
            MAIN.postDelayed(new Runnable() {
                @Override
                public void run() {
                    captureErrorText(activity);
                    if (last) {
                        flushSnapshot(activity);
                    }
                }
            }, CAPTURE_DELAYS[index]);
        }
    }

    /** 每次抓取只保留最长的一份内容，页面写完后才落盘 */
    private static void captureErrorText(Activity activity) {
        try {
            String text = collectErrorText(activity.getWindow().getDecorView());
            if (text == null) {
                return;
            }
            synchronized (PENDING) {
                String previous = PENDING.get(activity);
                if (previous == null || text.length() > previous.length()) {
                    PENDING.put(activity, text);
                }
            }
        } catch (Throwable ignored) {
            // 抓取失败不能影响页面
        }
    }

    private static void flushSnapshot(Activity activity) {
        final String text;
        synchronized (PENDING) {
            text = PENDING.remove(activity);
        }
        if (text == null) {
            return;
        }
        synchronized (SEEN_ERROR) {
            if (text.equals(SEEN_ERROR.get(activity))) {
                return;
            }
            SEEN_ERROR.put(activity, text);
        }
        LogCore.luaError("界面错误 " + activity.getClass().getName(), text);
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
