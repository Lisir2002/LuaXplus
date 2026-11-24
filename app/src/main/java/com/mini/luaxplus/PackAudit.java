package com.mini.luaxplus;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Enumeration;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;
import java.util.zip.ZipOutputStream;

/**
 * 打包前审计基础 APK 中的 DEX，找出只包含编译器类、没有本应用类定义的 DEX。
 *
 * 成品 APK 只负责运行已经编译好的 Java 页面，不需要在手机里再次编译，
 * 因此这类 DEX 可以从成品中剔除。DEX 字符串池会保留跨 DEX 的引用字符串，
 * 不能只看字符串判断；这里读取 class_defs 表，按真实类定义统计。
 */
public final class PackAudit {

    private static final int HEADER_CLASS_DEFS_SIZE = 0x60;
    private static final int HEADER_CLASS_DEFS_OFF = 0x64;
    private static final int HEADER_STRING_IDS_SIZE = 0x38;
    private static final int HEADER_STRING_IDS_OFF = 0x3C;
    private static final int HEADER_TYPE_IDS_OFF = 0x44;
    private static final int CLASS_DEF_ITEM_SIZE = 32;

    private static final String COMPILER_PREFIX_R8 = "Lcom/android/tools/r8/";
    private static final String COMPILER_PREFIX_ECJ = "Lorg/eclipse/jdt/";
    private static final String APP_PREFIX = "Lcom/mini/luaxplus/";

    /** 成品必须带上的主程序日志与崩溃入口；LuaApplication 是 MiniApplication 的父类 */
    private static final String[] REQUIRED_LOG_CLASSES = {
            "Lcom/mini/luaxplus/LogCore;",
            "Lcom/mini/luaxplus/LogPolicy;",
            "Lcom/mini/luaxplus/LogInjection;",
            "Lcom/mini/luaxplus/BootTrace;",
            "Lcom/mini/luaxplus/RuntimeWatcher;",
            "Lcom/mini/luaxplus/NativeCrashGuard;",
            "Lcom/mini/luaxplus/CrashBootstrapProvider;",
            "Lcom/mini/luaxplus/MiniApplication;",
            "Lcom/mini/luaxplus/CrashLedger;",
            "Lcom/mini/luaxplus/ExitHistory;",
            "Lcom/androlua/LuaApplication;",
            "Lcom/androlua/CrashHandler;",
    };

    private PackAudit() {
    }

    /** 在成品 ZIP 里写入一个 UTF-8 文本资源，供打包脚本生成配置使用 */
    public static void writeText(ZipOutputStream output, String entryName, String text)
            throws IOException {
        ZipEntry entry = new ZipEntry(entryName);
        output.putNextEntry(entry);
        output.write((text == null ? "" : text).getBytes(StandardCharsets.UTF_8));
        output.closeEntry();
    }

    /** 检查成品是否完整带上日志系统；返回缺失的类描述符，全部存在时返回空数组 */
    public static String[] missingLogClasses(String apkPath) throws IOException {
        if (apkPath == null || apkPath.isEmpty()) {
            return REQUIRED_LOG_CLASSES.clone();
        }
        Set<String> found = new HashSet<>();
        try (ZipFile zip = new ZipFile(apkPath)) {
            Enumeration<? extends ZipEntry> entries = zip.entries();
            while (entries.hasMoreElements()) {
                ZipEntry entry = entries.nextElement();
                String name = entry.getName();
                if (!name.matches("classes[0-9]*\\.dex")) {
                    continue;
                }
                byte[] data = readEntry(zip.getInputStream(entry));
                for (String descriptor : classDescriptors(data)) {
                    if (descriptor.startsWith(APP_PREFIX)
                            || descriptor.startsWith("Lcom/androlua/")) {
                        found.add(descriptor);
                    }
                }
            }
        }
        List<String> missing = new ArrayList<>();
        for (String required : REQUIRED_LOG_CLASSES) {
            if (!found.contains(required)) {
                missing.add(required);
            }
        }
        return missing.toArray(new String[0]);
    }

    /**
     * 只要成品携带了任意原生库，就必须同时携带原生崩溃守卫；纯 Java 成品没有 .so 时跳过。
     * 返回缺失的 ABI（例如 arm64-v8a），全部具备时返回空数组。
     */
    public static String[] missingNativeCrashGuard(String apkPath) throws IOException {
        if (apkPath == null || apkPath.isEmpty()) {
            return new String[0];
        }
        Set<String> abis = new HashSet<>();
        Set<String> guarded = new HashSet<>();
        try (ZipFile zip = new ZipFile(apkPath)) {
            Enumeration<? extends ZipEntry> entries = zip.entries();
            while (entries.hasMoreElements()) {
                ZipEntry entry = entries.nextElement();
                String name = entry.getName();
                if (!name.startsWith("lib/") || !name.endsWith(".so")) {
                    continue;
                }
                String[] parts = name.split("/");
                if (parts.length < 3) {
                    continue;
                }
                String abi = parts[1];
                abis.add(abi);
                if (parts[2].equals("libcrashguard.so")) {
                    guarded.add(abi);
                }
            }
        }
        List<String> missing = new ArrayList<>();
        for (String abi : abis) {
            if (!guarded.contains(abi)) {
                missing.add(abi);
            }
        }
        return missing.toArray(new String[0]);
    }

    public static String[] compilerOnlyDex(String apkPath) throws IOException {
        List<String> result = new ArrayList<>();
        if (apkPath == null || apkPath.isEmpty()) {
            return new String[0];
        }
        try (ZipFile zip = new ZipFile(apkPath)) {
            Enumeration<? extends ZipEntry> entries = zip.entries();
            while (entries.hasMoreElements()) {
                ZipEntry entry = entries.nextElement();
                String name = entry.getName();
                if (!name.matches("classes[0-9]*\\.dex")) {
                    continue;
                }
                byte[] data = readEntry(zip.getInputStream(entry));
                boolean hasCompiler = false;
                boolean hasRuntime = false;
                for (String descriptor : classDescriptors(data)) {
                    if (descriptor.startsWith(COMPILER_PREFIX_R8)
                            || descriptor.startsWith(COMPILER_PREFIX_ECJ)) {
                        hasCompiler = true;
                    } else {
                        // 除了编译器，只要还有一个运行时类，这个 DEX 就不能整块删除。
                        // 典型情况：LuaApplication/CrashHandler 与编译器被 R8 分在同一个 DEX。
                        hasRuntime = true;
                    }
                }
                if (hasCompiler && !hasRuntime) {
                    result.add(name);
                }
            }
        }
        return result.toArray(new String[0]);
    }

    private static byte[] readEntry(InputStream input) throws IOException {
        try (InputStream source = input) {
            byte[] buffer = new byte[8192];
            java.io.ByteArrayOutputStream output = new java.io.ByteArrayOutputStream();
            int read;
            while ((read = source.read(buffer)) != -1) {
                output.write(buffer, 0, read);
            }
            return output.toByteArray();
        }
    }

    /** 读取 DEX class_defs 中的类描述符，只取定义，不扫描引用字符串。 */
    private static List<String> classDescriptors(byte[] data) {
        List<String> descriptors = new ArrayList<>();
        if (data.length < HEADER_CLASS_DEFS_OFF + 4) {
            return descriptors;
        }
        int stringIdsSize = readInt(data, HEADER_STRING_IDS_SIZE);
        int stringIdsOff = readInt(data, HEADER_STRING_IDS_OFF);
        int typeIdsOff = readInt(data, HEADER_TYPE_IDS_OFF);
        int classDefsSize = readInt(data, HEADER_CLASS_DEFS_SIZE);
        int classDefsOff = readInt(data, HEADER_CLASS_DEFS_OFF);
        if (stringIdsSize <= 0 || stringIdsOff <= 0 || typeIdsOff <= 0
                || classDefsSize <= 0 || classDefsOff <= 0) {
            return descriptors;
        }
        for (int index = 0; index < classDefsSize; index++) {
            int itemOff = classDefsOff + index * CLASS_DEF_ITEM_SIZE;
            if (itemOff + 4 > data.length) {
                break;
            }
            int classIndex = readInt(data, itemOff);
            int typeOff = typeIdsOff + classIndex * 4;
            if (typeOff + 4 > data.length) {
                continue;
            }
            int stringIndex = readInt(data, typeOff);
            String descriptor = stringAt(data, stringIdsOff, stringIndex);
            if (descriptor != null) {
                descriptors.add(descriptor);
            }
        }
        return descriptors;
    }

    private static String stringAt(byte[] data, int stringIdsOff, int index) {
        int offset = stringIdsOff + index * 4;
        if (offset + 4 > data.length) {
            return null;
        }
        int stringDataOff = readInt(data, offset);
        if (stringDataOff <= 0 || stringDataOff >= data.length) {
            return null;
        }
        int length = readUleb128(data, stringDataOff);
        int start = stringDataOff + ulebSize(data, stringDataOff);
        if (length < 0 || start + length > data.length) {
            return null;
        }
        return new String(data, start, length, StandardCharsets.UTF_8);
    }

    private static int readUleb128(byte[] data, int offset) {
        int result = 0;
        int shift = 0;
        int cursor = offset;
        while (cursor < data.length && shift < 35) {
            int value = data[cursor] & 0xff;
            result |= (value & 0x7f) << shift;
            cursor++;
            if ((value & 0x80) == 0) {
                break;
            }
            shift += 7;
        }
        return result;
    }

    private static int ulebSize(byte[] data, int offset) {
        int size = 0;
        int cursor = offset;
        while (cursor < data.length && size < 5) {
            size++;
            if ((data[cursor] & 0x80) == 0) {
                break;
            }
            cursor++;
        }
        return size;
    }

    private static int readInt(byte[] data, int offset) {
        return (data[offset] & 0xff)
                | ((data[offset + 1] & 0xff) << 8)
                | ((data[offset + 2] & 0xff) << 16)
                | ((data[offset + 3] & 0xff) << 24);
    }
}
