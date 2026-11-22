package com.mini.luaxplus;

import android.app.Activity;
import android.app.Application;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;

import com.androlua.LuaActivity;

/**
 * 成品包的权限申请时机：等脚本首屏真正显示后再弹出系统授权页。
 * 启动页只负责铺设脚本与拉起应用，不再抢在界面之前跳转设置。
 */
public final class LaunchPermissions {

    private static final long DELAY_MS = 1000L;

    private static Application boundApplication;
    private static boolean pending;

    private LaunchPermissions() {
    }

    /**
     * 每次冷启动由启动页调用，等待第一个脚本页面进入前台后触发一次申请。
     */
    public static void arm(Application application) {
        if (application == null) {
            return;
        }
        pending = true;
        if (application == boundApplication) {
            return;
        }
        boundApplication = application;
        application.registerActivityLifecycleCallbacks(new Application.ActivityLifecycleCallbacks() {
            @Override
            public void onActivityCreated(Activity activity, Bundle savedInstanceState) {
            }

            @Override
            public void onActivityStarted(Activity activity) {
            }

            @Override
            public void onActivityResumed(Activity activity) {
                if (!pending || !(activity instanceof LuaActivity)) {
                    return;
                }
                pending = false;
                final Activity target = activity;
                new Handler(Looper.getMainLooper()).postDelayed(new Runnable() {
                    @Override
                    public void run() {
                        if (!target.isFinishing()) {
                            Permissions.requestAllFiles(target);
                        }
                    }
                }, DELAY_MS);
            }

            @Override
            public void onActivityPaused(Activity activity) {
            }

            @Override
            public void onActivityStopped(Activity activity) {
            }

            @Override
            public void onActivitySaveInstanceState(Activity activity, Bundle outState) {
            }

            @Override
            public void onActivityDestroyed(Activity activity) {
            }
        });
    }
}
