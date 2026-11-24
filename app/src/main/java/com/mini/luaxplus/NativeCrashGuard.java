package com.mini.luaxplus;

import android.util.Log;

/**
 * 原生崩溃守卫：接管 SIGABRT/SIGSEGV 等致命信号，先把现场写入日志目录，
 * 再交还系统默认处理，保留系统 tombstone 与调试信息。
 */
public final class NativeCrashGuard {

    private static final String TAG = "NativeCrashGuard";
    private static boolean installed;

    private NativeCrashGuard() {
    }

    public static boolean isInstalled() {
        return installed;
    }

    public static void install(String... logDirs) {
        String primary = "";
        String secondary = "";
        if (logDirs != null && logDirs.length > 0 && logDirs[0] != null) {
            primary = logDirs[0];
        }
        if (logDirs != null && logDirs.length > 1 && logDirs[1] != null) {
            secondary = logDirs[1];
        }
        if (installed) {
            BootTrace.mark("NativeCrashGuard already installed");
            return;
        }
        BootTrace.mark("NativeCrashGuard load begin");
        try {
            System.loadLibrary("crashguard");
            installNative(primary, secondary);
            installed = true;
            BootTrace.mark("NativeCrashGuard load done");
            LogCore.i(TAG, "原生崩溃守卫已启用 dir=" + primary + " second=" + secondary);
        } catch (Throwable throwable) {
            BootTrace.mark("NativeCrashGuard load failed " + throwable);
            // 守卫加载失败不能阻断应用启动
            Log.w(TAG, "原生崩溃守卫不可用", throwable);
        }
    }

    private static native void installNative(String primary, String secondary);
}
