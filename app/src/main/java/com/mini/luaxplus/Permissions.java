package com.mini.luaxplus;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.Settings;

/**
 * 运行时权限工具：成品包脚本无需各自实现授权流程，
 * 直接引用本类按需一次申请即可。
 */
public final class Permissions {

    private static final int REQUEST_CODE = 3100;

    private Permissions() {
    }

    /** 是否已获得某项运行时权限 */
    public static boolean granted(Context context, String permission) {
        if (Build.VERSION.SDK_INT < 23) {
            return true;
        }
        return context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED;
    }

    /** 批量申请，多个权限用英文逗号分隔 */
    public static void request(Activity activity, String permissions) {
        if (activity == null || permissions == null || permissions.trim().isEmpty()) {
            return;
        }
        if (Build.VERSION.SDK_INT < 23) {
            return;
        }
        String[] items = permissions.split(",");
        activity.requestPermissions(items, REQUEST_CODE);
    }

    /** 是否已获得所有文件访问权限 */
    public static boolean allFiles() {
        return Build.VERSION.SDK_INT < 30 || Environment.isExternalStorageManager();
    }

    /** 申请所有文件访问权限；低版本走存储写入权限 */
    public static void requestAllFiles(Activity activity) {
        if (activity == null) {
            return;
        }
        try {
            if (Build.VERSION.SDK_INT >= 30) {
                if (!Environment.isExternalStorageManager()) {
                    Intent intent = new Intent(
                            Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                            Uri.parse("package:" + activity.getPackageName()));
                    activity.startActivity(intent);
                }
            } else if (Build.VERSION.SDK_INT >= 23
                    && !granted(activity, android.Manifest.permission.WRITE_EXTERNAL_STORAGE)) {
                request(activity, android.Manifest.permission.WRITE_EXTERNAL_STORAGE);
            }
        } catch (Exception exception) {
            LogCore.w("Permissions", "申请所有文件访问失败: " + exception);
        }
    }
}
