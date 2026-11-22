package com.mini.luaxplus;

import android.app.Activity;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.Settings;

/**
 * 运行时权限工具：主程序首次启动只主动申请存储，网络权限属于普通权限由系统安装时授予。
 * 其他敏感权限不再自动弹窗，统一由设置页的“权限管理”里按需开启。
 */
public final class Permissions {

    private static final int REQUEST_CODE = 3100;
    private static final String PREFS_NAME = "mini_luaxplus_permissions";
    private static final String KEY_FIRST_LAUNCH = "first_launch_storage_requested";

    private Permissions() {
    }

    /** 是否已获得某项运行时权限 */
    public static boolean granted(Context context, String permission) {
        if (context == null || permission == null) {
            return false;
        }
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
        String[] raw = permissions.split(",");
        java.util.ArrayList<String> items = new java.util.ArrayList<>();
        for (String item : raw) {
            String trimmed = item == null ? "" : item.trim();
            if (!trimmed.isEmpty()) {
                items.add(trimmed);
            }
        }
        if (!items.isEmpty()) {
            activity.requestPermissions(items.toArray(new String[0]), REQUEST_CODE);
        }
    }

    /** 首次启动标记：只读偏好，不在每次启动重复检查权限状态 */
    public static boolean firstLaunchDone(Context context) {
        if (context == null) {
            return true;
        }
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .getBoolean(KEY_FIRST_LAUNCH, false);
    }

    /** 记录首次启动已经主动申请过存储权限，之后不再自动弹窗 */
    public static void markFirstLaunchDone(Context context) {
        if (context == null) {
            return;
        }
        SharedPreferences preferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        preferences.edit().putBoolean(KEY_FIRST_LAUNCH, true).apply();
    }

    /** 首次启动只申请存储：Android 11+ 走所有文件访问页，低版本走运行时存储权限 */
    public static void requestStorage(Activity activity) {
        if (activity == null) {
            return;
        }
        if (Build.VERSION.SDK_INT >= 30) {
            if (!allFiles()) {
                openAllFilesSettings(activity);
            }
            return;
        }
        if (Build.VERSION.SDK_INT >= 23) {
            String missing = storagePermissionString(activity);
            if (!missing.isEmpty()) {
                request(activity, missing);
            }
        }
    }

    private static String storagePermissionString(Context context) {
        StringBuilder builder = new StringBuilder();
        if (!granted(context, android.Manifest.permission.READ_EXTERNAL_STORAGE)) {
            builder.append(android.Manifest.permission.READ_EXTERNAL_STORAGE);
        }
        if (!granted(context, android.Manifest.permission.WRITE_EXTERNAL_STORAGE)) {
            if (builder.length() > 0) {
                builder.append(',');
            }
            builder.append(android.Manifest.permission.WRITE_EXTERNAL_STORAGE);
        }
        return builder.toString();
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
        if (Build.VERSION.SDK_INT >= 30) {
            if (!allFiles()) {
                openAllFilesSettings(activity);
            }
        } else {
            requestStorage(activity);
        }
    }

    public static void openAppSettings(Activity activity) {
        if (activity == null) {
            return;
        }
        try {
            activity.startActivity(new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:" + activity.getPackageName())));
        } catch (Exception exception) {
            LogCore.w("Permissions", "打开应用设置页失败: " + exception);
        }
    }

    public static void openAllFilesSettings(Activity activity) {
        if (activity == null) {
            return;
        }
        if (Build.VERSION.SDK_INT < 30) {
            requestStorage(activity);
            return;
        }
        Intent intent = new Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                Uri.parse("package:" + activity.getPackageName()));
        try {
            activity.startActivity(intent);
        } catch (Exception exception) {
            LogCore.w("Permissions", "打开所有文件访问页失败，尝试列表页: " + exception);
            try {
                activity.startActivity(new Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION));
            } catch (Exception fallback) {
                LogCore.w("Permissions", "打开所有文件访问列表失败: " + fallback);
                openAppSettings(activity);
            }
        }
    }

    public static void openWriteSettings(Activity activity) {
        if (activity == null) {
            return;
        }
        Intent intent = new Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS,
                Uri.parse("package:" + activity.getPackageName()));
        startSafely(activity, intent);
    }

    public static void openInstallSettings(Activity activity) {
        if (activity == null) {
            return;
        }
        Intent intent = new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:" + activity.getPackageName()));
        startSafely(activity, intent);
    }

    public static void openNotificationPolicySettings(Activity activity) {
        startSafely(activity, new Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS));
    }

    public static void openOverlaySettings(Activity activity) {
        if (activity == null) {
            return;
        }
        Intent intent = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:" + activity.getPackageName()));
        startSafely(activity, intent);
    }

    public static void openAccessibilitySettings(Activity activity) {
        startSafely(activity, new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS));
    }

    public static void openNotificationListenerSettings(Activity activity) {
        startSafely(activity, new Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS));
    }

    public static void openUsageAccessSettings(Activity activity) {
        startSafely(activity, new Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS));
    }

    public static boolean writeSettingsGranted(Context context) {
        return Build.VERSION.SDK_INT < 23 || Settings.System.canWrite(context);
    }

    public static boolean installPackagesGranted(Context context) {
        return Build.VERSION.SDK_INT < 26 || context.getPackageManager().canRequestPackageInstalls();
    }

    public static boolean notificationPolicyGranted(Context context) {
        if (Build.VERSION.SDK_INT < 23) {
            return true;
        }
        NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        return manager != null && manager.isNotificationPolicyAccessGranted();
    }

    public static boolean overlayGranted(Context context) {
        return Build.VERSION.SDK_INT < 23 || Settings.canDrawOverlays(context);
    }

    /** 无障碍服务是否在系统里启用 */
    public static boolean accessibilityEnabled(Context context) {
        String enabled = Settings.Secure.getString(
                context.getContentResolver(), Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES);
        if (enabled == null) {
            return false;
        }
        String packageName = context.getPackageName();
        return enabled.contains(packageName + "/com.androlua.LuaAccessibilityService")
                || enabled.contains(packageName + "/.LuaAccessibilityService");
    }

    private static void startSafely(Activity activity, Intent intent) {
        if (activity == null || intent == null) {
            return;
        }
        try {
            activity.startActivity(intent);
        } catch (Exception exception) {
            // 这里不再回退 openAppSettings，避免设置页本身不可用时递归调用。
            LogCore.w("Permissions", "打开系统设置失败: " + exception);
        }
    }
}
