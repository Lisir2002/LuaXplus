package com.mini.luaxplus;

import android.content.Context;
import android.content.SharedPreferences;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.Date;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

/**
 * 成品崩溃账本：把 Java 异常、原生信号、系统退出/ANR 统一落成可读文件。
 *
 * 文件默认写在成品自己的外部私有目录 logs 下，工程日志页可以只按成品包名读取；
 * 每条记录还尽量通过 MediaStore 导出到系统下载目录，作为用户可见的兜底入口。
 */
public final class CrashLedger {

    public static final String SOURCE_JAVA = "JAVA";
    public static final String SOURCE_NATIVE = "NATIVE";
    public static final String SOURCE_EXIT = "EXIT";

    private static final String PREFS = "luaxplus_crash_ledger";
    private static final String KEY_READ = "read";
    private static final String KEY_SEEN = "seen";
    private static final String HEADER = "MINI_LUAXPLUS_CRASH";
    private static final String CLOCK_PATTERN = "yyyyMMdd_HHmmss_SSS";
    private static final int MAX_FILES = 30;
    private static final int MAX_DETAIL_CHARS = 256 * 1024;
    private static final Object LOCK = new Object();
    private static final SimpleDateFormat CLOCK =
            new SimpleDateFormat(CLOCK_PATTERN, Locale.US);

    private CrashLedger() {
    }

    public static final class Entry {
        public final String id;
        public final String path;
        public final String source;
        public final String title;
        public final String detail;
        public final long time;

        Entry(String id, String path, String source, String title, String detail, long time) {
            this.id = id;
            this.path = path;
            this.source = source;
            this.title = title;
            this.detail = detail;
            this.time = time;
        }
    }

    /** 与运行日志共用同一目录；优先 LuaXPlus/APP_Logs/<包名>，不可写时退回应用私有目录。 */
    public static File dir(Context context) {
        if (context == null) {
            return null;
        }
        String coreDir = LogCore.dir();
        if (coreDir != null && !coreDir.trim().isEmpty()) {
            File candidate = new File(coreDir);
            if (usable(candidate)) {
                return candidate;
            }
        }
        File base = null;
        try {
            base = context.getExternalFilesDir(null);
        } catch (Throwable ignored) {
            // 外部目录不可用时退回内部目录
        }
        File parent = base == null ? context.getFilesDir() : base;
        if (parent == null) {
            return null;
        }
        File logs = new File(parent, "logs");
        return usable(logs) ? logs : null;
    }

    private static boolean usable(File dir) {
        try {
            if (!dir.exists() && !dir.mkdirs()) {
                return false;
            }
            return dir.isDirectory() && dir.canWrite();
        } catch (Throwable ignored) {
            return false;
        }
    }

    /**
     * 写入一条崩溃记录。recordId 相同的记录只写一次，用于系统退出历史和原生崩溃文件去重。
     */
    public static Entry record(Context context, String source, String title, String detail,
                               String filePath, String recordId) {
        if (context == null) {
            return null;
        }
        synchronized (LOCK) {
            File folder = dir(context);
            if (folder == null) {
                return null;
            }
            if (recordId != null && recordId.trim().isEmpty()) {
                recordId = null;
            }
            SharedPreferences preferences = prefs(context);
            Set<String> seen = new HashSet<>(preferences.getStringSet(KEY_SEEN,
                    Collections.<String>emptySet()));
            if (recordId != null && seen.contains(recordId)) {
                return null;
            }

            String safeSource = safeToken(source, "UNKNOWN");
            String safeId = recordId == null
                    ? System.currentTimeMillis() + "_" + System.nanoTime()
                    : safeToken(recordId, Long.toString(System.currentTimeMillis()));
            long now = System.currentTimeMillis();
            String fileName = "crash_ledger_" + CLOCK.format(new Date(now)) + "_"
                    + safeSource + "_" + safeId + ".log";
            File target = new File(folder, fileName);
            if (target.exists()) {
                return null;
            }

            String cleanTitle = oneLine(title, safeSource);
            String cleanFile = oneLine(filePath, "");
            String body = detail == null ? "" : detail;
            if (body.length() > MAX_DETAIL_CHARS) {
                body = body.substring(0, MAX_DETAIL_CHARS) + "\n…（内容过长已截断）";
            }
            StringBuilder content = new StringBuilder();
            content.append(HEADER).append('\n');
            content.append("source=").append(safeSource).append('\n');
            content.append("id=").append(safeId).append('\n');
            content.append("time=").append(now).append('\n');
            content.append("file=").append(cleanFile).append('\n');
            content.append("title=").append(cleanTitle).append('\n');
            content.append("detail:\n").append(body);

            write(target, content.toString());

            if (recordId != null) {
                seen.add(recordId);
                if (seen.size() > 200) {
                    seen = trim(seen, 200);
                }
                preferences.edit().putStringSet(KEY_SEEN, seen).apply();
            }
            cleanup(folder);

            // 额外导出到系统下载目录；导出失败不影响本地文件。
            LogCore.exportText(context, fileName, content.toString());
            return new Entry(fileName, target.getAbsolutePath(), safeSource,
                    cleanTitle, body, now);
        }
    }

    /** 返回尚未被用户确认过的记录，最多 limit 条，按时间从新到旧。 */
    public static List<Entry> unread(Context context, int limit) {
        List<Entry> result = new ArrayList<>();
        if (context == null) {
            return result;
        }
        synchronized (LOCK) {
            File folder = dir(context);
            if (folder == null) {
                return result;
            }
            Set<String> read = new HashSet<>(prefs(context).getStringSet(KEY_READ,
                    Collections.<String>emptySet()));
            List<Entry> all = list(folder);
            for (Entry entry : all) {
                if (!read.contains(entry.id)) {
                    result.add(entry);
                    if (result.size() >= Math.max(1, limit)) {
                        break;
                    }
                }
            }
        }
        return result;
    }

    /** 用户看到并关闭崩溃报告后，才把这些记录标记为已读。 */
    public static void markRead(Context context, List<Entry> entries) {
        if (context == null || entries == null || entries.isEmpty()) {
            return;
        }
        synchronized (LOCK) {
            SharedPreferences preferences = prefs(context);
            Set<String> read = new HashSet<>(preferences.getStringSet(KEY_READ,
                    Collections.<String>emptySet()));
            for (Entry entry : entries) {
                if (entry != null && entry.id != null) {
                    read.add(entry.id);
                }
            }
            if (read.size() > 200) {
                read = trim(read, 200);
            }
            preferences.edit().putStringSet(KEY_READ, read).apply();
        }
    }

    /**
     * 把上一进程原生守卫留下的 native_crash_*.log 导入账本。
     * 原生信号处理器已经写完文件，下一次启动只负责把它变成可展示的报告。
     */
    public static void importNative(Context context) {
        if (context == null) {
            return;
        }
        Set<String> folders = new HashSet<>();
        for (String path : BootTrace.dirs()) {
            if (path != null && !path.trim().isEmpty()) {
                folders.add(path);
            }
        }
        String logDir = LogCore.dir();
        if (logDir != null && !logDir.trim().isEmpty()) {
            folders.add(logDir);
        }
        File ledgerDir = dir(context);
        if (ledgerDir != null) {
            folders.add(ledgerDir.getAbsolutePath());
        }
        for (String folderPath : folders) {
            File folder = new File(folderPath);
            File[] files = folder.listFiles();
            if (files == null) {
                continue;
            }
            for (File file : files) {
                if (file == null || !file.isFile()
                        || !file.getName().startsWith("native_crash_")) {
                    continue;
                }
                String raw = read(file);
                if (raw == null || raw.isEmpty()) {
                    continue;
                }
                record(context, SOURCE_NATIVE, "原生崩溃：" + file.getName(), raw,
                        file.getAbsolutePath(), "native_file:" + file.getName());
            }
        }
    }

    /**
     * 把旧版本用 SharedPreferences 保存的单条 Java 崩溃迁移到账本，
     * 迁移后清空旧标记，避免升级后丢失上一次崩溃。
     */
    public static void importLegacy(Context context) {
        if (context == null) {
            return;
        }
        try {
            SharedPreferences legacy = context.getSharedPreferences(
                    "luaxplus_packaged_crash", Context.MODE_PRIVATE);
            String stack = legacy.getString("stack", null);
            if (stack == null || stack.trim().isEmpty()) {
                return;
            }
            long time = legacy.getLong("time", System.currentTimeMillis());
            String file = legacy.getString("file", "");
            record(context, SOURCE_JAVA, "旧版 Java 崩溃", stack, file, "legacy_" + time);
            legacy.edit().clear().apply();
        } catch (Throwable ignored) {
            // 旧版迁移失败不影响新账本
        }
    }

    private static List<Entry> list(File folder) {
        List<Entry> entries = new ArrayList<>();
        File[] files = folder.listFiles();
        if (files == null) {
            return entries;
        }
        for (File file : files) {
            if (file == null || !file.isFile()
                    || !file.getName().startsWith("crash_ledger_")
                    || !file.getName().endsWith(".log")) {
                continue;
            }
            Entry entry = parse(file);
            if (entry != null) {
                entries.add(entry);
            }
        }
        Collections.sort(entries, new Comparator<Entry>() {
            @Override
            public int compare(Entry left, Entry right) {
                return Long.compare(right.time, left.time);
            }
        });
        return entries;
    }

    private static Entry parse(File file) {
        String text = read(file);
        if (text == null || !text.startsWith(HEADER)) {
            return null;
        }
        String source = "UNKNOWN";
        String title = file.getName();
        String filePath = "";
        long time = file.lastModified();
        int detailIndex = text.indexOf("detail:\n");
        String detail = detailIndex >= 0 ? text.substring(detailIndex + "detail:\n".length()) : text;
        for (String line : text.split("\n")) {
            if (line.startsWith("source=")) {
                source = line.substring("source=".length()).trim();
            } else if (line.startsWith("title=")) {
                title = line.substring("title=".length()).trim();
            } else if (line.startsWith("file=")) {
                filePath = line.substring("file=".length()).trim();
            } else if (line.startsWith("time=")) {
                try {
                    time = Long.parseLong(line.substring("time=".length()).trim());
                } catch (NumberFormatException ignored) {
                    // 使用文件修改时间兜底
                }
            }
        }
        if (title.isEmpty()) {
            title = file.getName();
        }
        return new Entry(file.getName(), filePath, source, title, detail, time);
    }

    private static void write(File file, String text) {
        FileOutputStream output = null;
        try {
            output = new FileOutputStream(file, false);
            output.write(text.getBytes(StandardCharsets.UTF_8));
            output.flush();
            try {
                output.getFD().sync();
            } catch (IOException ignored) {
                // 部分文件系统不支持 sync，flush 已保证进程内可见
            }
        } catch (Throwable throwable) {
            android.util.Log.e("CrashLedger", "写入失败 " + file, throwable);
        } finally {
            if (output != null) {
                try {
                    output.close();
                } catch (IOException ignored) {
                }
            }
        }
    }

    private static String read(File file) {
        FileInputStream input = null;
        try {
            input = new FileInputStream(file);
            ByteArrayOutputStream output = new ByteArrayOutputStream();
            byte[] buffer = new byte[8192];
            int count;
            int total = 0;
            while ((count = input.read(buffer)) != -1 && total < MAX_DETAIL_CHARS + 1024) {
                output.write(buffer, 0, count);
                total += count;
            }
            return output.toString(StandardCharsets.UTF_8.name());
        } catch (Throwable ignored) {
            return null;
        } finally {
            if (input != null) {
                try {
                    input.close();
                } catch (IOException ignored) {
                }
            }
        }
    }

    private static SharedPreferences prefs(Context context) {
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    private static void cleanup(File folder) {
        File[] files = folder.listFiles();
        if (files == null || files.length <= MAX_FILES) {
            return;
        }
        List<File> logs = new ArrayList<>();
        for (File file : files) {
            if (file != null && file.isFile() && file.getName().startsWith("crash_ledger_")) {
                logs.add(file);
            }
        }
        Collections.sort(logs, new Comparator<File>() {
            @Override
            public int compare(File left, File right) {
                return Long.compare(left.lastModified(), right.lastModified());
            }
        });
        for (int index = 0; index < logs.size() - MAX_FILES; index++) {
            logs.get(index).delete();
        }
    }

    private static Set<String> trim(Set<String> values, int max) {
        if (values.size() <= max) {
            return values;
        }
        List<String> list = new ArrayList<>(values);
        Collections.sort(list);
        Set<String> result = new HashSet<>();
        for (int index = list.size() - max; index < list.size(); index++) {
            result.add(list.get(index));
        }
        return result;
    }

    private static String safeToken(String value, String fallback) {
        if (value == null) {
            return fallback;
        }
        String text = value.trim().replaceAll("[^A-Za-z0-9_.-]", "_");
        if (text.length() > 48) {
            text = text.substring(0, 48);
        }
        return text.isEmpty() ? fallback : text;
    }

    private static String oneLine(String value, String fallback) {
        if (value == null) {
            return fallback;
        }
        String text = value.replace('\r', ' ').replace('\n', ' ').trim();
        if (text.length() > 256) {
            text = text.substring(0, 256);
        }
        return text.isEmpty() ? fallback : text;
    }
}
