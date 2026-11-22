package com.mini.luaxplus;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Context;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;

import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.appcompat.app.AppCompatActivity;


import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.WeakHashMap;

/**
 * 首屏权限引导：按功能分组逐组弹出系统授权框，全部处理完后再引导“所有文件访问”。
 * 普通权限在安装时已由系统授予，特殊权限仍需用户在系统设置中手动打开，本类不会绕过系统限制。
 */
public final class StartupPermissions {

    private static final Handler MAIN = new Handler(Looper.getMainLooper());
    private static final Map<AppCompatActivity, Session> SESSIONS = new WeakHashMap<>();

    @SuppressLint("InlinedApi")
    private static final String[][] GROUPS = {
            {Manifest.permission.READ_CONTACTS, Manifest.permission.WRITE_CONTACTS},
            {Manifest.permission.READ_CALENDAR, Manifest.permission.WRITE_CALENDAR},
            {Manifest.permission.READ_CALL_LOG, Manifest.permission.WRITE_CALL_LOG},
            {Manifest.permission.READ_PHONE_STATE, Manifest.permission.READ_PHONE_NUMBERS,
                    Manifest.permission.CALL_PHONE, Manifest.permission.ANSWER_PHONE_CALLS},
            {Manifest.permission.READ_SMS, Manifest.permission.RECEIVE_SMS,
                    Manifest.permission.RECEIVE_MMS, Manifest.permission.SEND_SMS},
            {Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO},
            {Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION},
            {Manifest.permission.ACCESS_BACKGROUND_LOCATION},
            {Manifest.permission.BODY_SENSORS, Manifest.permission.ACTIVITY_RECOGNITION},
            {Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT,
                    Manifest.permission.BLUETOOTH_ADVERTISE, Manifest.permission.NEARBY_WIFI_DEVICES},
            {Manifest.permission.POST_NOTIFICATIONS},
            {Manifest.permission.READ_MEDIA_IMAGES, Manifest.permission.READ_MEDIA_VIDEO,
                    Manifest.permission.READ_MEDIA_AUDIO, Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED},
            {Manifest.permission.ACCESS_MEDIA_LOCATION},
            {Manifest.permission.READ_EXTERNAL_STORAGE, Manifest.permission.WRITE_EXTERNAL_STORAGE}
    };

    private StartupPermissions() {
    }

    /** 在首屏 Activity 创建阶段调用；同一 Activity 只引导一次。 */
    public static void request(Activity activity) {
        if (activity == null || activity.isFinishing()) {
            return;
        }
        if (!(activity instanceof AppCompatActivity)) {
            String[] missing = missingAll(activity);
            if (missing.length > 0) {
                Permissions.request(activity, join(missing));
            }
            return;
        }
        AppCompatActivity host = (AppCompatActivity) activity;
        if (SESSIONS.containsKey(host)) {
            return;
        }
        if (Build.VERSION.SDK_INT < 23) {
            Permissions.requestAllFiles(host);
            return;
        }
        try {
            Session session = new Session(host);
            SESSIONS.put(host, session);
            session.start();
        } catch (RuntimeException e) {
            // 生命周期已不在 CREATED 时无法注册结果回调，退回系统批量申请，仍由用户逐项确认。
            String[] missing = missingAll(host);
            if (missing.length > 0) {
                Permissions.request(host, join(missing));
            }
            if (!Permissions.allFiles()) {
                Permissions.requestAllFiles(host);
            }
        }
    }

    private static String[] missingAll(Context context) {
        List<String> result = new ArrayList<>();
        for (String[] group : GROUPS) {
            for (String permission : group) {
                if (applies(permission) && !Permissions.granted(context, permission)) {
                    result.add(permission);
                }
            }
        }
        return result.toArray(new String[0]);
    }

    private static String join(String[] items) {
        StringBuilder builder = new StringBuilder();
        for (String item : items) {
            if (builder.length() > 0) {
                builder.append(',');
            }
            builder.append(item);
        }
        return builder.toString();
    }

    private static boolean applies(String permission) {
        if (permission.equals(Manifest.permission.POST_NOTIFICATIONS)) {
            return Build.VERSION.SDK_INT >= 33;
        }
        if (permission.equals(Manifest.permission.READ_MEDIA_IMAGES)
                || permission.equals(Manifest.permission.READ_MEDIA_VIDEO)
                || permission.equals(Manifest.permission.READ_MEDIA_AUDIO)) {
            return Build.VERSION.SDK_INT >= 33;
        }
        if (permission.equals(Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED)) {
            return Build.VERSION.SDK_INT >= 34;
        }
        if (permission.equals(Manifest.permission.BLUETOOTH_SCAN)
                || permission.equals(Manifest.permission.BLUETOOTH_CONNECT)
                || permission.equals(Manifest.permission.BLUETOOTH_ADVERTISE)) {
            return Build.VERSION.SDK_INT >= 31;
        }
        if (permission.equals(Manifest.permission.NEARBY_WIFI_DEVICES)) {
            return Build.VERSION.SDK_INT >= 33;
        }
        if (permission.equals(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
                || permission.equals(Manifest.permission.ACTIVITY_RECOGNITION)) {
            return Build.VERSION.SDK_INT >= 29;
        }
        if (permission.equals(Manifest.permission.ACCESS_MEDIA_LOCATION)) {
            return Build.VERSION.SDK_INT >= 29;
        }
        if (permission.equals(Manifest.permission.READ_PHONE_NUMBERS)
                || permission.equals(Manifest.permission.ANSWER_PHONE_CALLS)) {
            return Build.VERSION.SDK_INT >= 26;
        }
        if (permission.equals(Manifest.permission.READ_EXTERNAL_STORAGE)
                || permission.equals(Manifest.permission.WRITE_EXTERNAL_STORAGE)) {
            return Build.VERSION.SDK_INT <= 32;
        }
        return true;
    }

    private static final class Session {
        private final AppCompatActivity activity;
        private final ActivityResultLauncher<String[]> launcher;
        private int index;

        Session(AppCompatActivity activity) {
            this.activity = activity;
            this.launcher = activity.registerForActivityResult(
                    new ActivityResultContracts.RequestMultiplePermissions(),
                    this::onResult);
        }

        void start() {
            next();
        }

        private void onResult(Map<String, Boolean> result) {
            index++;
            MAIN.postDelayed(this::next, 150L);
        }

        private void next() {
            if (activity.isFinishing() || activity.isDestroyed()) {
                SESSIONS.remove(activity);
                return;
            }
            while (index < GROUPS.length) {
                String[] group = GROUPS[index];
                List<String> missing = new ArrayList<>();
                for (String permission : group) {
                    if (applies(permission)
                            && !Permissions.granted(activity, permission)
                            && declared(permission)) {
                        missing.add(permission);
                    }
                }
                if (!missing.isEmpty()) {
                    launcher.launch(missing.toArray(new String[0]));
                    return;
                }
                index++;
            }
            SESSIONS.remove(activity);
            if (!Permissions.allFiles()) {
                MAIN.postDelayed(() -> Permissions.requestAllFiles(activity), 150L);
            }
        }

        private boolean declared(String permission) {
            try {
                activity.getPackageManager().getPermissionInfo(permission, 0);
                return true;
            } catch (Exception e) {
                return false;
            }
        }
    }
}
