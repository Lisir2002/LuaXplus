package com.mini.luaxplus;

import android.app.Activity;

/**
 * 首启权限引导：只在应用第一次启动时主动申请存储，网络属于普通权限无需申请。
 * 其余敏感权限不在这里自动申请，统一放到设置页的“权限管理”里由用户开启。
 */
public final class StartupPermissions {

    private StartupPermissions() {
    }

    public static void request(Activity activity) {
        if (activity == null || activity.isFinishing()) {
            return;
        }
        if (Permissions.firstLaunchDone(activity)) {
            return;
        }
        Permissions.markFirstLaunchDone(activity);
        Permissions.requestStorage(activity);
    }
}
