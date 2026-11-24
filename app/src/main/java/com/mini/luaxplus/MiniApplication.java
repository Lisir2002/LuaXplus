package com.mini.luaxplus;

import android.content.Context;
import android.util.Log;

import com.androlua.LuaApplication;

/**
 * 应用入口：在 Application 最早阶段启用启动轨迹、统一日志、Java 崩溃捕获和原生信号捕获，
 * 保证 Application 初始化、Activity 启动和原生 abort 都能留下可读取的快照。
 */
public class MiniApplication extends LuaApplication {

    private static final String TAG = "MiniApplication";

    @Override
    protected void attachBaseContext(Context base) {
        BootTrace.init(base);
        BootTrace.mark("MiniApplication.attachBaseContext");
        // 在 super.attachBaseContext 之前先初始化日志并装好 Java 崩溃处理器，
        // 这样父类 attach 或 Application 早期初始化失败也能留下现场的 Java 堆栈。
        try {
            LogCore.init(base);
        } catch (Throwable throwable) {
            BootTrace.crash(throwable, Thread.currentThread());
        }
        try {
            RuntimeWatcher.setContext(base);
            RuntimeWatcher.installCrashHandler();
            NativeCrashGuard.install(LogCore.dir(), BootTrace.dir());
        } catch (Throwable throwable) {
            BootTrace.crash(throwable, Thread.currentThread());
        }
        super.attachBaseContext(base);
        BootTrace.mark("Application base attached");
        try {
            LogCore.init(this);
            RuntimeWatcher.setContext(this);
            RuntimeWatcher.refreshCrashHandler();
            NativeCrashGuard.install(LogCore.dir(), BootTrace.dir());
            BootTrace.mark("Application guards ready");
        } catch (Throwable throwable) {
            BootTrace.crash(throwable, Thread.currentThread());
        }
    }

    @Override
    public void onCreate() {
        BootTrace.mark("MiniApplication.onCreate enter");
        try {
            LogCore.init(this);
            RuntimeWatcher.installCrashHandler();
            NativeCrashGuard.install(LogCore.dir(), BootTrace.dir());
        } catch (Throwable throwable) {
            BootTrace.crash(throwable, Thread.currentThread());
        }

        BootTrace.mark("before super.onCreate");
        try {
            super.onCreate();
        } catch (Throwable throwable) {
            BootTrace.crash(throwable, Thread.currentThread());
            throw throwable;
        }
        BootTrace.mark("after super.onCreate");

        try {
            BootTrace.mark("before refreshCrashHandler");
            RuntimeWatcher.refreshCrashHandler();
            BootTrace.mark("after refreshCrashHandler");
        } catch (Throwable throwable) {
            BootTrace.crash(throwable, Thread.currentThread());
            Log.e(TAG, "崩溃处理器重接管失败", throwable);
        }

        try {
            BootTrace.mark("before RuntimeWatcher.install");
            RuntimeWatcher.install(this);
            BootTrace.mark("after RuntimeWatcher.install");
        } catch (Throwable throwable) {
            BootTrace.crash(throwable, Thread.currentThread());
            Log.e(TAG, "运行监控初始化失败", throwable);
        }

        try {
            BootTrace.mark("before native guard final install");
            NativeCrashGuard.install(LogCore.dir(), BootTrace.dir());
            BootTrace.mark("after native guard final install installed="
                    + NativeCrashGuard.isInstalled());
        } catch (Throwable throwable) {
            BootTrace.crash(throwable, Thread.currentThread());
            Log.e(TAG, "原生守卫最终安装失败", throwable);
        }

        try {
            LogCore.i(TAG, "应用入口初始化完成 trace=" + BootTrace.path());
            BootTrace.mark("MiniApplication.onCreate complete");
        } catch (Throwable throwable) {
            BootTrace.crash(throwable, Thread.currentThread());
            Log.e(TAG, "应用入口日志收尾失败", throwable);
        }
    }
}
