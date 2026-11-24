package com.mini.luaxplus;

import android.content.ContentValues;
import android.content.Context;
import android.content.pm.PackageInfo;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.MediaStore;
import android.util.Log;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
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
 * 统一日志落盘核心：主程序写入 LuaXPlus/logs，子应用成品写入
 * LuaXPlus/APP_Logs/<包名>/；未获得公共存储授权时退回应用私有目录。
 */
public final class LogCore {

    /** 外部存储根目录 */
    public static final String EXT_ROOT = "/storage/emulated/0/LuaXPlus";
    /** 主程序包名，用于区分本应用与打包成品 */
    public static final String OWNER_PACKAGE = "com.mini.luaxplus";

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
            new SimpleDateFormat("yyyyMMdd_HHmmss_SSS", Locale.US);

    private static Context appContext;
    private static File activeDir;
    private static File activeFile;
    private static Writer writer;
    private static String activeDay = "";
    private static int part = 1;
    private static boolean external;
    private static boolean initialized;
    private static long lastExternalRetry;
    private static String lastLuaMessage;
    private static long lastLuaTime;
    private static String lastJavaMessage;
    private static long lastJavaTime;
    private static String lastWarnMessage;
    private static long lastWarnTime;
    private static String lastCrashFile;
    private static String lastCrashExport;

    private LogCore() {
    }

    /** 应用启动时最早调用一次，之后直接使用静态方法写日志 */
    public static void init(Context context) {
        synchronized (LOCK) {
            if (initialized) {
                return;
            }
            appContext = context.getApplicationContext();
            if (appContext == null) {
                appContext = context;
            }
            external = prepareExternal();
            activeDir = external ? new File(extLogDir()) : internalDir();
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
            return activeDir == null ? extLogDir() : activeDir.getAbsolutePath();
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

    /** 警告：写入运行日志的同时留一份快照，便于回溯 */
    public static void w(String tag, String message) {
        write("W", tag, message);
        warnSnapshot(tag, message);
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
            long now = System.currentTimeMillis();
            String signature = (message == null ? "" : message) + "|"
                    + (traceback == null ? "" : traceback.substring(0, Math.min(200, traceback.length())));
            if (signature.equals(lastLuaMessage) && now - lastLuaTime < 3000L) {
                write("W", "Lua", "重复错误在 3 秒内出现，仅记录到运行日志: " + message);
                return;
            }
            lastLuaMessage = signature;
            lastLuaTime = now;
        }
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

    /** 记录 Java 编译或页面加载异常，保留独立快照和完整堆栈 */
    public static void javaError(String message, Throwable error) {
        String summary = message == null || message.trim().isEmpty()
                ? "Java 运行时异常" : message;
        String detail = error == null ? "unknown" : error.toString();
        write("E", "Java", summary + " | " + detail);
        synchronized (LOCK) {
            long now = System.currentTimeMillis();
            String signature = summary + "|" + detail;
            if (signature.equals(lastJavaMessage) && now - lastJavaTime < 5000L) {
                return;
            }
            lastJavaMessage = signature;
            lastJavaTime = now;
            ensureReady();
            if (activeDir == null) {
                return;
            }
            File target = new File(activeDir, "javaerror_" + CLOCK.format(new Date())
                    + "_" + android.os.Process.myPid() + ".log");
            StringBuilder body = new StringBuilder();
            body.append("时间: ").append(STAMP.format(new Date())).append('\n');
            body.append("版本: ").append(versionName()).append('\n');
            body.append("进程: ").append(android.os.Process.myPid()).append('\n');
            body.append("线程: ").append(Thread.currentThread().getName()).append('\n');
            body.append("设备: ").append(Build.MANUFACTURER).append(' ').append(Build.MODEL)
                    .append(" / Android ").append(Build.VERSION.RELEASE)
                    .append(" (API ").append(Build.VERSION.SDK_INT).append(")\n");
            body.append("来源: ").append(summary).append('\n');
            if (error != null) {
                StringWriter stringWriter = new StringWriter();
                PrintWriter printWriter = new PrintWriter(stringWriter);
                error.printStackTrace(printWriter);
                printWriter.flush();
                body.append("堆栈:\n").append(stringWriter.toString());
            }
            try {
                appendToFile(target, body.toString());
            } catch (Exception exception) {
                write("E", "Java", "异常快照写入失败: " + exception + " | " + summary);
            }
        }
    }

    /** 记录警告快照，短时间内重复的同一警告只留首次 */
    public static void warnSnapshot(String tag, String message) {
        synchronized (LOCK) {
            long now = System.currentTimeMillis();
            if (message == null || (message.equals(lastWarnMessage) && now - lastWarnTime < 5000L)) {
                return;
            }
            lastWarnMessage = message;
            lastWarnTime = now;
            ensureReady();
            File target = new File(activeDir, "warn_" + CLOCK.format(new Date())
                    + "_" + android.os.Process.myPid() + ".log");
            StringBuilder body = new StringBuilder();
            body.append("时间: ").append(STAMP.format(new Date())).append('\n');
            body.append("版本: ").append(versionName()).append('\n');
            body.append("线程: ").append(Thread.currentThread().getName()).append('\n');
            body.append("来源: ").append(tag).append('\n');
            body.append("警告: ").append(message).append('\n');
            appendToFile(target, body.toString());
        }
    }

    /** 崩溃快照导出到系统下载目录后的路径，便于用户直接取回 */
    public static String lastCrashExport() {
        synchronized (LOCK) {
            return lastCrashExport == null ? "" : lastCrashExport;
        }
    }

    /** 最近一次崩溃快照文件，供成品崩溃报告读取 */
    public static String lastCrashFile() {
        synchronized (LOCK) {
            return lastCrashFile == null ? "" : lastCrashFile;
        }
    }

    /** 当前应用上下文，供崩溃处理器在 Application 早期阶段使用 */
    public static Context context() {
        synchronized (LOCK) {
            return appContext;
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
            lastCrashFile = target.getAbsolutePath();
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
            exportCrash(target, body.toString());
        }
    }

    /** 把崩溃快照额外导出到系统下载目录，Android 10 起无需存储权限即可被用户取回 */
    private static void exportCrash(File source, String body) {
        String exported = exportText(appContext, source.getName(), body);
        if (!exported.isEmpty()) {
            lastCrashExport = exported;
        }
    }

    /**
     * 把任意崩溃/退出报告导出到系统下载目录。
     * 返回相对路径；Android 10 以下或不支持 MediaStore 的场景返回空字符串，
     * 调用方仍应保留应用私有或外部私有目录里的文件。
     */
    public static String exportText(Context context, String displayName, String body) {
        if (context == null || Build.VERSION.SDK_INT < 29) {
            return "";
        }
        try {
            String pkg = context.getPackageName();
            ContentValues values = new ContentValues();
            values.put(MediaStore.MediaColumns.DISPLAY_NAME, displayName);
            values.put(MediaStore.MediaColumns.MIME_TYPE, "text/plain");
            values.put(MediaStore.MediaColumns.RELATIVE_PATH,
                    Environment.DIRECTORY_DOWNLOADS + "/Mini-LuaXPLUS/" + pkg + "/logs");
            Object collection = Class.forName("android.provider.MediaStore$Downloads")
                    .getField("EXTERNAL_CONTENT_URI").get(null);
            Uri uri = context.getContentResolver().insert((Uri) collection, values);
            if (uri == null) {
                return "";
            }
            try (OutputStream output = context.getContentResolver().openOutputStream(uri)) {
                if (output == null) {
                    return "";
                }
                output.write(body.getBytes("UTF-8"));
                output.flush();
            }
            return "Download/Mini-LuaXPLUS/" + pkg + "/logs/" + displayName;
        } catch (Throwable ignored) {
            // 导出只是辅助手段，失败不能影响本地日志
            return "";
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

    /** 外部日志目录：主程序写 logs，子应用成品统一写 APP_Logs/<包名>/ */
    public static String extLogDir() {
        String pkg = appContext == null ? OWNER_PACKAGE : appContext.getPackageName();
        if (OWNER_PACKAGE.equals(pkg)) {
            return EXT_ROOT + "/logs";
        }
        return EXT_ROOT + "/APP_Logs/" + safePackage(pkg);
    }

    /** 包名作为目录名时只保留安全字符，避免异常包名造成路径穿越 */
    static String safePackage(String pkg) {
        if (pkg == null || pkg.trim().isEmpty()) {
            return "unknown";
        }
        return pkg.trim().replaceAll("[^A-Za-z0-9_.]", "_");
    }

    private static File internalDir() {
        File base = appContext == null ? new File(EXT_ROOT) : appContext.getFilesDir();
        // 成品在未拿到公共存储授权时，优先写应用专属外部目录，
        // 这样崩溃日志仍可通过文件管理器或工程日志页读取。
        if (appContext != null && !OWNER_PACKAGE.equals(appContext.getPackageName())) {
            File external = appContext.getExternalFilesDir(null);
            if (external != null) {
                base = external;
            }
        }
        return new File(base, "logs");
    }

    private static boolean prepareExternal() {
        File dir = new File(extLogDir());
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
        } catch (Throwable throwable) {
            return false;
        }
    }

    private static void switchExternalIfPossible(long now) {
        if (external || appContext == null || now - lastExternalRetry < RETRY_EXTERNAL_MILLIS) {
            return;
        }
        lastExternalRetry = now;
        if (Build.VERSION.SDK_INT >= 30) {
            try {
                if (!Environment.isExternalStorageManager()) {
                    return;
                }
            } catch (Throwable throwable) {
                // Application.attach 阶段包名尚未就绪，部分 ROM 会在这里抛空指针
                return;
            }
        }
        if (prepareExternal()) {
            external = true;
            closeWriter();
            activeDir = new File(extLogDir());
            activeFile = null;
            activeDay = "";
            part = 1;
            write("I", "Log", "外部存储已授权，日志切换至 " + extLogDir());
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
            // 崩溃账本与崩溃快照是用户要取回的现场，不能被日常运行日志的
            // 过期清理一并删掉；账本自身由 CrashLedger.cleanup 控制数量。
            if (f.getName().startsWith("crash_")
                    || f.getName().startsWith("native_crash_")) {
                continue;
            }
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
            if (files[index].getName().startsWith("crash_")
                    || files[index].getName().startsWith("native_crash_")) {
                continue;
            }
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
