package com.mini.luaxplus;

import android.content.Context;
import android.os.Build;
import android.util.Log;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;

/**
 * 进程级启动轨迹与崩溃落盘。只依赖 Android 基础 API，不依赖 Lua、日志框架或界面，
 * 因此可以在 Application 创建之前由 ContentProvider 调用。
 */
public final class BootTrace {

    private static final String TAG = "BootTrace";
    private static final String BOOT_FILE = "boot_trace.log";
    private static final SimpleDateFormat TIME =
            new SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US);
    private static final SimpleDateFormat FILE_TIME =
            new SimpleDateFormat("yyyyMMdd_HHmmss_SSS", Locale.US);
    private static final Object LOCK = new Object();
    private static final List<File> DIRS = new ArrayList<>();
    private static File primaryDir;
    private static Context appContext;
    private static boolean initialized;

    private BootTrace() {
    }

    public static void init(Context context) {
        synchronized (LOCK) {
            if (initialized || context == null) {
                return;
            }
            try {
                appContext = context.getApplicationContext();
                if (appContext == null) {
                    appContext = context;
                }
            } catch (Throwable throwable) {
                appContext = context;
            }
            addDir(safeExternalFilesDir(context));
            String pkg = "";
            try {
                pkg = context.getPackageName();
            } catch (Throwable throwable) {
                Log.w(TAG, "package name unavailable", throwable);
            }
            if (!pkg.isEmpty() && !"com.mini.luaxplus".equals(pkg)) {
                addDir(new File(LogCore.EXT_ROOT + "/APP_Logs/"
                        + pkg.replaceAll("[^A-Za-z0-9_.]", "_")));
            }
            addDir(safeFilesDir(context));
            addDir(safeCacheDir(context));
            addDir(safeDir(context, "boot"));
            if ("com.mini.luaxplus".equals(pkg)) {
                addDir(new File(LogCore.EXT_ROOT + "/logs"));
                addDir(new File("/sdcard/androlua/crash"));
            }
            initialized = true;
            mark("BootTrace init dirs=" + DIRS.size() + " primary="
                    + (primaryDir == null ? "none" : primaryDir.getAbsolutePath()));
        }
    }

    private static File safeExternalFilesDir(Context context) {
        try {
            return context.getExternalFilesDir(null);
        } catch (Throwable throwable) {
            Log.w(TAG, "external files dir unavailable", throwable);
            return null;
        }
    }

    private static File safeFilesDir(Context context) {
        try {
            return context.getFilesDir();
        } catch (Throwable throwable) {
            Log.w(TAG, "files dir unavailable", throwable);
            return null;
        }
    }

    private static File safeCacheDir(Context context) {
        try {
            return context.getCacheDir();
        } catch (Throwable throwable) {
            Log.w(TAG, "cache dir unavailable", throwable);
            return null;
        }
    }

    private static File safeDir(Context context, String name) {
        try {
            return context.getDir(name, Context.MODE_PRIVATE);
        } catch (Throwable throwable) {
            Log.w(TAG, "private dir unavailable: " + name, throwable);
            return null;
        }
    }

    private static void addDir(File dir) {
        if (dir == null) {
            return;
        }
        try {
            if (!dir.exists()) {
                dir.mkdirs();
            }
            if (!dir.isDirectory() || !dir.canWrite()) {
                return;
            }
            for (File item : DIRS) {
                if (item.getAbsolutePath().equals(dir.getAbsolutePath())) {
                    return;
                }
            }
            DIRS.add(dir);
            if (primaryDir == null) {
                primaryDir = dir;
            }
        } catch (Throwable throwable) {
            Log.w(TAG, "log dir unavailable: " + dir, throwable);
        }
    }

    public static String[] dirs() {
        synchronized (LOCK) {
            String[] values = new String[DIRS.size()];
            for (int index = 0; index < DIRS.size(); index++) {
                values[index] = DIRS.get(index).getAbsolutePath();
            }
            return values;
        }
    }

    public static String dir() {
        synchronized (LOCK) {
            return primaryDir == null ? "" : primaryDir.getAbsolutePath();
        }
    }

    public static String path() {
        synchronized (LOCK) {
            return primaryDir == null ? "" : new File(primaryDir, BOOT_FILE).getAbsolutePath();
        }
    }

    public static void mark(String stage) {
        Log.i(TAG, stage);
        append(BOOT_FILE, line("I", stage));
    }

    public static void crash(Throwable throwable, Thread thread) {
        StringBuilder body = new StringBuilder();
        body.append(line("E", "CRASH thread=" + (thread == null ? "unknown" : thread.getName())));
        body.append("版本: ").append(versionName()).append('\n');
        body.append("设备: ").append(Build.MANUFACTURER).append(' ').append(Build.MODEL)
                .append(" / Android ").append(Build.VERSION.RELEASE)
                .append(" (API ").append(Build.VERSION.SDK_INT).append(")\n");
        if (throwable != null) {
            body.append("异常: ").append(throwable).append('\n');
            java.io.StringWriter stringWriter = new java.io.StringWriter();
            java.io.PrintWriter printWriter = new java.io.PrintWriter(stringWriter);
            throwable.printStackTrace(printWriter);
            printWriter.flush();
            body.append(stringWriter).append('\n');
        }
        Log.e(TAG, body.toString());
        append(BOOT_FILE, body.toString());
        File crashFile = new File("crash_" + FILE_TIME.format(new Date()) + ".log");
        writeAll(crashFile.getName(), body.toString());
    }

    private static String versionName() {
        try {
            if (appContext != null) {
                return appContext.getPackageManager()
                        .getPackageInfo(appContext.getPackageName(), 0).versionName;
            }
        } catch (Throwable ignored) {
            // 版本读取失败不能影响崩溃记录
        }
        return "unknown";
    }

    private static String line(String level, String message) {
        return TIME.format(new Date()) + " " + level + "/"
                + Thread.currentThread().getName() + " " + message + "\n";
    }

    private static void append(String fileName, String text) {
        writeAll(fileName, text);
    }

    private static void writeAll(String fileName, String text) {
        synchronized (LOCK) {
            for (File dir : DIRS) {
                FileOutputStream output = null;
                try {
                    output = new FileOutputStream(new File(dir, fileName), true);
                    output.write(text.getBytes("UTF-8"));
                    output.flush();
                    try {
                        output.getFD().sync();
                    } catch (IOException ignored) {
                        // 部分文件系统不支持 sync，flush 已保证进程内可见
                    }
                } catch (Throwable throwable) {
                    Log.e(TAG, "write failed " + dir + "/" + fileName, throwable);
                } finally {
                    if (output != null) {
                        try {
                            output.close();
                        } catch (IOException ignored) {
                        }
                    }
                }
            }
        }
    }
}
