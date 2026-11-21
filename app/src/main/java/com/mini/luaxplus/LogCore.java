package com.mini.luaxplus;

import android.content.Context;
import android.content.pm.PackageInfo;
import android.os.Build;
import android.os.Environment;
import android.util.Log;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.io.Writer;
import java.text.SimpleDateFormat;
import java.util.Arrays;
import java.util.Comparator;
import java.util.Date;
import java.util.Locale;

/**
 * 统一日志落盘核心：外部存储可用时写入 LuaXPlus/logs，
 * 未获得存储授权时退回应用私有目录，保证任何阶段都有日志可查。
 */
public final class LogCore {

    /** 外部日志目录 */
    public static final String EXT_LOG_DIR = "/storage/emulated/0/LuaXPlus/logs";

    private static final String TAG = "LogCore";
    private static final long MAX_FILE_BYTES = 2L * 1024 * 1024L;
    private static final int MAX_FILES = 40;
    private static final long KEEP_MILLIS = 7L * 24L * 3600L * 1000L;
    private static final long RETRY_EXTERNAL_MILLIS = 30L * 1000L;

    private static final Object LOCK = new Object();
    private static final SimpleDateFormat STAMP =
            new SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US);
    private static final SimpleDateFormat DAY =
            new SimpleDateFormat("yyyyMMdd", Locale.US);
    private static final SimpleDateFormat CLOCK =
            new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US);

    private static Context appContext;
    private static File activeDir;
    private static File activeFile;
    private static Writer writer;
    private static String activeDay = "";
    private static int part = 1;
    private static boolean external;
    private static boolean initialized;
    private static long lastExternalRetry;

    private LogCore() {
    }

    /** 应用启动时最早调用一次，之后直接使用静态方法写日志 */
    public static void init(Context context) {
        synchronized (LOCK) {
            if (initialized) {
                return;
            }
            appContext = context.getApplicationContext();
            external = prepareExternal();
            activeDir = external ? new File(EXT_LOG_DIR) : internalDir();
            if (!activeDir.exists()) {
                activeDir.mkdirs();
            }
            initialized = true;
            cleanOldFiles();
            write("I", "Log", "日志初始化 version=" + versionName()
                    + " sdk=" + Build.VERSION.SDK_INT
                    + " device=" + Build.MANUFACTURER + " " + Build.MODEL
                    + " dir=" + activeDir.getAbsolutePath());
            if (!external) {
                write("W", "Log", "外部存储不可写，日志暂存应用私有目录，授权后自动切换");
            }
        }
    }

    /** 当前日志目录，供界面展示 */
    public static String dir() {
        synchronized (LOCK) {
            return activeDir == null ? EXT_LOG_DIR : activeDir.getAbsolutePath();
        }
    }

    /** 当前日志文件，供界面展示 */
    public static String file() {
        synchronized (LOCK) {
            return activeFile == null ? "" : activeFile.getAbsolutePath();
        }
    }

    public static void i(String tag, String message) {
        write("I", tag, message);
    }

    public static void w(String tag, String message) {
        write("W", tag, message);
    }

    public static void e(String tag, String message) {
        write("E", tag, message);
    }

    public static void d(String tag, String message) {
        write("D", tag, message);
    }

    /** 记录 Lua 运行时错误，单独成文件便于定位 */
    public static void luaError(String message, String traceback) {
        write("E", "Lua", message);
        synchronized (LOCK) {
            ensureReady();
            File target = new File(activeDir, "luaerror_" + CLOCK.format(new Date()) + ".log");
            StringBuilder body = new StringBuilder();
            body.append("时间: ").append(STAMP.format(new Date())).append('\n');
            body.append("版本: ").append(versionName()).append('\n');
            body.append("线程: ").append(Thread.currentThread().getName()).append('\n');
            body.append("错误: ").append(message == null ? "" : message).append('\n');
            if (traceback != null && traceback.length() > 0) {
                body.append("堆栈:\n").append(traceback).append('\n');
            }
            try {
                appendToFile(target, body.toString());
            } catch (Exception exception) {
                // 独立文件写不进去时退回主日志，保证错误不丢
                write("E", "Lua", message + " (独立日志写入失败: " + exception + ")");
            }
        }
    }

    /** 记录未捕获异常，单独成文件，保留完整堆栈与设备信息 */
    public static void crash(Throwable throwable, Thread thread) {
        String summary = throwable == null ? "unknown" : throwable.toString();
        write("E", "Crash", summary);
        synchronized (LOCK) {
            ensureReady();
            File target = new File(activeDir, "crash_" + CLOCK.format(new Date())
                    + "_" + android.os.Process.myPid() + ".log");
            StringBuilder body = new StringBuilder();
            body.append("时间: ").append(STAMP.format(new Date())).append('\n');
            body.append("版本: ").append(versionName()).append('\n');
            body.append("进程: ").append(android.os.Process.myPid()).append('\n');
            body.append("线程: ").append(thread == null ? "unknown" : thread.getName()).append('\n');
            body.append("设备: ").append(Build.MANUFACTURER).append(' ').append(Build.MODEL)
                    .append(" / Android ").append(Build.VERSION.RELEASE)
                    .append(" (API ").append(Build.VERSION.SDK_INT).append(")\n");
            if (throwable != null) {
                StringWriter stringWriter = new StringWriter();
                PrintWriter printWriter = new PrintWriter(stringWriter);
                throwable.printStackTrace(printWriter);
                printWriter.flush();
                body.append("堆栈:\n").append(stringWriter.toString());
            }
            appendToFile(target, body.toString());
        }
    }

    private static void write(String level, String tag, String message) {
        if (message == null) {
            message = "";
        }
        synchronized (LOCK) {
            if (!initialized) {
                Log.println(level.equals("E") ? Log.ERROR : Log.INFO, tag, message);
                return;
            }
            long now = System.currentTimeMillis();
            switchExternalIfPossible(now);
            ensureReady();
            File target = pickFile(now);
            String line = STAMP.format(new Date(now)) + " " + level + "/" + tag
                    + "(" + android.os.Process.myPid() + ") " + message + "\n";
            try {
                writeLine(line);
            } catch (IOException ioException) {
                Log.e(TAG, "写入日志失败: " + ioException);
                resetWriter();
                try {
                    writeLine(line);
                } catch (IOException ignored) {
                    Log.e(TAG, "日志落盘彻底失败，目标=" + target);
                }
            }
        }
    }

    private static void ensureReady() {
        if (activeDir == null && appContext != null) {
            activeDir = internalDir();
        }
        if (activeDir != null && !activeDir.exists()) {
            activeDir.mkdirs();
        }
    }

    private static void writeLine(String line) throws IOException {
        if (writer == null) {
            Log.println(Log.INFO, TAG, line);
            return;
        }
        writer.write(line);
        writer.flush();
    }

    private static File pickFile(long now) {
        String day = DAY.format(new Date(now));
        File base = new File(activeDir, "app_" + day + ".log");
        if (activeFile == null || !activeDay.equals(day)) {
            closeWriter();
            activeDay = day;
            part = 1;
            activeFile = base;
        }
        if (activeFile.length() >= MAX_FILE_BYTES) {
            part++;
            closeWriter();
            activeFile = new File(activeDir, "app_" + day + "_" + part + ".log");
        }
        if (writer == null) {
            try {
                writer = new OutputStreamWriter(new FileOutputStream(activeFile, true), "UTF-8");
            } catch (IOException ioException) {
                Log.e(TAG, "打开日志文件失败: " + ioException);
            }
        }
        return activeFile;
    }

    private static void closeWriter() {
        if (writer != null) {
            try {
                writer.close();
            } catch (IOException ignored) {
                // 关闭失败不影响后续写入
            }
            writer = null;
        }
    }

    private static void resetWriter() {
        closeWriter();
    }

    private static void appendToFile(File target, String body) {
        FileOutputStream outputStream = null;
        try {
            outputStream = new FileOutputStream(target, true);
            outputStream.write(body.getBytes("UTF-8"));
            outputStream.flush();
        } catch (IOException ioException) {
            Log.e(TAG, "写入独立日志失败: " + ioException);
        } finally {
            if (outputStream != null) {
                try {
                    outputStream.close();
                } catch (IOException ignored) {
                    // 关闭失败忽略
                }
            }
        }
    }

    private static File internalDir() {
        File base = appContext == null ? new File(EXT_LOG_DIR) : appContext.getFilesDir();
        return new File(base, "logs");
    }

    private static boolean prepareExternal() {
        File dir = new File(EXT_LOG_DIR);
        if (!dir.exists() && !dir.mkdirs()) {
            return false;
        }
        File probe = new File(dir, ".probe");
        try {
            if (!probe.exists()) {
                probe.createNewFile();
            }
            boolean writable = probe.canWrite();
            probe.delete();
            return writable;
        } catch (IOException ioException) {
            return false;
        }
    }

    private static void switchExternalIfPossible(long now) {
        if (external || now - lastExternalRetry < RETRY_EXTERNAL_MILLIS) {
            return;
        }
        lastExternalRetry = now;
        if (Build.VERSION.SDK_INT >= 30
                && !Environment.isExternalStorageManager()) {
            return;
        }
        if (prepareExternal()) {
            external = true;
            closeWriter();
            activeDir = new File(EXT_LOG_DIR);
            activeFile = null;
            activeDay = "";
            part = 1;
            write("I", "Log", "外部存储已授权，日志切换至 " + EXT_LOG_DIR);
        }
    }

    private static void cleanOldFiles() {
        if (activeDir == null) {
            return;
        }
        File[] files = activeDir.listFiles();
        if (files == null) {
            return;
        }
        long now = System.currentTimeMillis();
        for (File f : files) {
            if (now - f.lastModified() > KEEP_MILLIS) {
                f.delete();
            }
        }
        files = activeDir.listFiles();
        if (files == null || files.length <= MAX_FILES) {
            return;
        }
        Arrays.sort(files, new Comparator<File>() {
            @Override
            public int compare(File left, File right) {
                return Long.compare(left.lastModified(), right.lastModified());
            }
        });
        int remove = files.length - MAX_FILES;
        for (int index = 0; index < remove; index++) {
            files[index].delete();
        }
    }

    private static String versionName() {
        if (appContext == null) {
            return "";
        }
        try {
            PackageInfo info = appContext.getPackageManager()
                    .getPackageInfo(appContext.getPackageName(), 0);
            return info.versionName == null ? "" : info.versionName;
        } catch (Exception exception) {
            return "";
        }
    }
}
