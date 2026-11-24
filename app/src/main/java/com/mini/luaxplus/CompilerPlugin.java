package com.mini.luaxplus;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.security.MessageDigest;
import java.util.Enumeration;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;

/**
 * Java 编译器插件：ECJ 与 D8 不再随主程序打包，而是按需下载后从这里加载。
 *
 * 插件目录固定放在应用内部存储 files/compiler-plugin，不依赖外部存储或存储权限，
 * 卸载应用时随应用数据一起清理。插件包固定包含 compiler.dex、android.jar 和
 * version.txt，安装前校验整包 SHA-256，运行时通过 DexClassLoader 提供 ECJ/D8 类，
 * 避免把约 34 MB 的编译链塞进 APK。
 */
public final class CompilerPlugin {

    private static final String TAG = "CompilerPlugin";
    private static final String INTERNAL_DIR = "compiler-plugin";
    private static final String DEX_NAME = "compiler.dex";
    private static final String ANDROID_JAR_NAME = "android.jar";
    private static final String VERSION_NAME = "version.txt";
    private static final String RESOURCES_DIR = "resources";
    private static final String RESOURCE_PREFIX = RESOURCES_DIR + "/";
    private static final String REQUIRED_RESOURCE =
            RESOURCE_PREFIX + "org/eclipse/jdt/internal/compiler/batch/messages.properties";
    private static final long MIN_DEX_BYTES = 1024L * 1024L;
    private static final long MIN_ANDROID_JAR_BYTES = 1024L * 1024L;
    private static final long MAX_DOWNLOAD_BYTES = 80L * 1024L * 1024L;

    private static volatile String lastError = "";
    private static ClassLoader compilerLoader;

    private CompilerPlugin() {
    }

    /** 插件目录固定使用应用内部存储，避免外部存储被清理或文件管理器误删。 */
    public static File root(Context context) {
        File internal = new File(context.getFilesDir(), INTERNAL_DIR);
        ensureDirectory(internal);
        return internal;
    }

    public static File dexFile(Context context) {
        return new File(root(context), DEX_NAME);
    }

    public static File androidJar(Context context) {
        return new File(root(context), ANDROID_JAR_NAME);
    }

    /** 编译前快速判断插件是否完整，避免把不完整的文件交给 ClassLoader。 */
    public static boolean isInstalled(Context context) {
        File dex = dexFile(context);
        File androidJar = androidJar(context);
        File resources = new File(root(context), REQUIRED_RESOURCE);
        return dex.isFile() && dex.length() >= MIN_DEX_BYTES
                && androidJar.isFile() && androidJar.length() >= MIN_ANDROID_JAR_BYTES
                && resources.isFile();
    }

    public static String installedVersion(Context context) {
        File version = new File(root(context), VERSION_NAME);
        if (!version.isFile()) {
            return "";
        }
        try (FileInputStream input = new FileInputStream(version)) {
            byte[] buffer = new byte[128];
            int read = input.read(buffer);
            if (read <= 0) {
                return "";
            }
            return new String(buffer, 0, read, "UTF-8").trim();
        } catch (IOException error) {
            return "";
        }
    }

    public static long installedBytes(Context context) {
        long size = 0L;
        File dex = dexFile(context);
        File androidJar = androidJar(context);
        if (dex.isFile()) {
            size += dex.length();
        }
        if (androidJar.isFile()) {
            size += androidJar.length();
        }
        return size;
    }

    public static String lastError() {
        return lastError == null ? "" : lastError;
    }

    /**
     * 下载并安装插件。方法会阻塞，调用方必须在后台线程执行。
     * expectedSha256 为空时不校验哈希，但仍会校验 ZIP 结构和文件大小。
     */
    public static boolean downloadAndInstall(Context context, String url, String expectedSha256) {
        lastError = "";
        File target = root(context);
        File part = new File(target, "compiler-plugin.zip.part");
        File zip = new File(target, "compiler-plugin.zip");
        HttpURLConnection connection = null;
        try {
            URL address = new URL(url);
            connection = (HttpURLConnection) address.openConnection();
            connection.setConnectTimeout(20000);
            connection.setReadTimeout(90000);
            connection.setInstanceFollowRedirects(true);
            connection.setUseCaches(false);
            connection.setRequestProperty("User-Agent", "Mini-LuaXPLUS/CompilerPlugin");
            int code = connection.getResponseCode();
            if (code < 200 || code >= 300) {
                throw new IOException("下载失败，HTTP " + code);
            }
            long expectedLength = connection.getContentLength();
            if (expectedLength > MAX_DOWNLOAD_BYTES) {
                throw new IOException("插件包超过大小上限");
            }
            try (InputStream input = connection.getInputStream();
                 OutputStream output = new FileOutputStream(part)) {
                byte[] buffer = new byte[32 * 1024];
                long total = 0L;
                int read;
                while ((read = input.read(buffer)) != -1) {
                    total += read;
                    if (total > MAX_DOWNLOAD_BYTES) {
                        throw new IOException("插件包超过大小上限");
                    }
                    output.write(buffer, 0, read);
                }
                output.flush();
            }
            if (part.length() < MIN_DEX_BYTES) {
                throw new IOException("下载内容不完整");
            }
            if (expectedSha256 != null && !expectedSha256.isEmpty()) {
                String actual = sha256(part);
                if (!expectedSha256.equalsIgnoreCase(actual)) {
                    throw new IOException("插件包校验失败，请重试");
                }
            }
            if (zip.exists() && !zip.delete()) {
                throw new IOException("无法清理旧插件包");
            }
            if (!part.renameTo(zip)) {
                throw new IOException("无法保存插件包");
            }
            boolean installed = installFromZip(context, zip);
            if (installed && zip.exists()) {
                zip.delete();
            }
            return installed;
        } catch (Throwable error) {
            lastError = error.getMessage() == null ? error.toString() : error.getMessage();
            Log.e(TAG, "下载编译器插件失败", error);
            if (part.exists()) {
                part.delete();
            }
            return false;
        } finally {
            if (connection != null) {
                connection.disconnect();
            }
        }
    }

    /** 安装完成回调；onResult 在界面线程执行，供 Lua 代理直接更新页面。 */
    public interface InstallCallback {
        void onResult(boolean installed, String error);
    }

    /** 后台下载并安装，避免 Lua 页面自己处理线程环境与变量隔离。 */
    public static void downloadAndInstallAsync(
            final Context context,
            final String url,
            final String expectedSha256,
            final InstallCallback callback) {
        final Context app = context.getApplicationContext();
        new Thread(new Runnable() {
            @Override
            public void run() {
                final boolean installed = downloadAndInstall(app, url, expectedSha256);
                final String error = lastError;
                new Handler(Looper.getMainLooper()).post(new Runnable() {
                    @Override
                    public void run() {
                        if (callback != null) {
                            callback.onResult(installed, error);
                        }
                    }
                });
            }
        }, "compiler-plugin").start();
    }

    /** 安装已经下载到本地的插件 ZIP；失败时返回 false，原因写入 lastError。 */
    public static boolean installFromZip(Context context, File zipFile) {
        lastError = "";
        File target = root(context);
        File staging = new File(target, ".install-" + System.currentTimeMillis());
        try {
            if (zipFile == null || !zipFile.isFile()) {
                throw new IOException("插件包不存在");
            }
            if (!ensureDirectory(staging)) {
                throw new IOException("无法创建安装临时目录");
            }
            try (ZipFile zip = new ZipFile(zipFile)) {
                extractEntry(zip, DEX_NAME, new File(staging, DEX_NAME), 64L * 1024L * 1024L);
                extractEntry(zip, ANDROID_JAR_NAME, new File(staging, ANDROID_JAR_NAME), 64L * 1024L * 1024L);
                ZipEntry versionEntry = zip.getEntry(VERSION_NAME);
                if (versionEntry != null) {
                    extractEntry(zip, VERSION_NAME, new File(staging, VERSION_NAME), 4096L);
                }
                extractResources(zip, new File(staging, RESOURCES_DIR));
            }
            File stagedDex = new File(staging, DEX_NAME);
            File stagedJar = new File(staging, ANDROID_JAR_NAME);
            if (stagedDex.length() < MIN_DEX_BYTES) {
                throw new IOException("插件 DEX 不完整");
            }
            if (stagedJar.length() < MIN_ANDROID_JAR_BYTES) {
                throw new IOException("插件 android.jar 不完整");
            }
            if (!hasDexMagic(stagedDex)) {
                throw new IOException("插件 DEX 格式无效");
            }

            // 先删旧文件再改名；插件文件都是本类管理的，不触碰用户文件。
            deleteIfExists(new File(target, DEX_NAME));
            deleteIfExists(new File(target, ANDROID_JAR_NAME));
            deleteIfExists(new File(target, VERSION_NAME));
            move(stagedDex, new File(target, DEX_NAME));
            move(stagedJar, new File(target, ANDROID_JAR_NAME));
            File stagedVersion = new File(staging, VERSION_NAME);
            if (stagedVersion.isFile()) {
                move(stagedVersion, new File(target, VERSION_NAME));
            } else {
                writeText(new File(target, VERSION_NAME), "1.0");
            }
            File stagedResources = new File(staging, RESOURCES_DIR);
            if (stagedResources.isDirectory()) {
                replaceTree(stagedResources, new File(target, RESOURCES_DIR));
            }
            if (!new File(target, REQUIRED_RESOURCE).isFile()) {
                throw new IOException("插件包缺少 ECJ 提示资源");
            }
            compilerLoader = null;
            return true;
        } catch (Throwable error) {
            lastError = error.getMessage() == null ? error.toString() : error.getMessage();
            Log.e(TAG, "安装编译器插件失败", error);
            return false;
        } finally {
            deleteTree(staging);
        }
    }

    /**
     * 为插件创建独立的 DexClassLoader。父加载器仍使用应用自身加载器，
     * 这样 javax/lang/model/SourceVersion 等宿主兼容类可以正常解析。
     */
    public static synchronized ClassLoader classLoader(Context context) throws IOException {
        if (!isInstalled(context)) {
            throw new IOException("Java 编译器插件未安装");
        }
        if (compilerLoader != null) {
            return compilerLoader;
        }
        File loadDex = prepareLoadDex(context);
        File optimized = new File(context.getCodeCacheDir(), "compiler-plugin");
        if (!ensureDirectory(optimized)) {
            optimized = new File(context.getFilesDir(), "compiler-plugin-oat");
            if (!ensureDirectory(optimized)) {
                throw new IOException("无法创建编译器缓存目录");
            }
        }
        File resources = new File(root(context), RESOURCES_DIR);
        compilerLoader = new PluginDexClassLoader(
                loadDex.getAbsolutePath(),
                optimized.getAbsolutePath(),
                null,
                context.getClassLoader(),
                resources);
        return compilerLoader;
    }

    /** 插件 DEX 固定在应用内部存储，直接交给 DexClassLoader 加载。 */
    private static File prepareLoadDex(Context context) throws IOException {
        File dex = dexFile(context);
        if (!dex.isFile() || dex.length() < MIN_DEX_BYTES) {
            throw new IOException("Java 编译器插件 DEX 不完整");
        }
        return dex;
    }

    private static boolean ensureDirectory(File directory) {
        if (directory.isDirectory()) {
            return true;
        }
        return directory.mkdirs() || directory.isDirectory();
    }

    private static void extractEntry(ZipFile zip, String name, File target, long maxBytes)
            throws IOException {
        ZipEntry entry = zip.getEntry(name);
        if (entry == null || entry.isDirectory()) {
            throw new IOException("插件包缺少 " + name);
        }
        if (entry.getSize() > maxBytes) {
            throw new IOException(name + " 超过大小上限");
        }
        try (InputStream input = zip.getInputStream(entry);
             OutputStream output = new FileOutputStream(target)) {
            byte[] buffer = new byte[32 * 1024];
            long total = 0L;
            int read;
            while ((read = input.read(buffer)) != -1) {
                total += read;
                if (total > maxBytes) {
                    throw new IOException(name + " 超过大小上限");
                }
                output.write(buffer, 0, read);
            }
            output.flush();
        }
    }

    /**
     * ECJ 的提示文本和 D8 的 API 数据库不是 class 文件，D8 转 DEX 时会丢失。
     * 插件把 resources/ 下的普通文件单独带上，由 PluginDexClassLoader 读取。
     */
    private static void extractResources(ZipFile zip, File targetRoot) throws IOException {
        Enumeration<? extends ZipEntry> entries = zip.entries();
        while (entries.hasMoreElements()) {
            ZipEntry entry = entries.nextElement();
            String name = entry.getName();
            if (!name.startsWith(RESOURCE_PREFIX) || entry.isDirectory()) {
                continue;
            }
            String relative = name.substring(RESOURCE_PREFIX.length());
            if (relative.isEmpty() || relative.startsWith("/") || relative.contains("..")) {
                throw new IOException("插件资源路径无效: " + name);
            }
            File target = new File(targetRoot, relative);
            File parent = target.getParentFile();
            if (parent != null && !ensureDirectory(parent)) {
                throw new IOException("无法创建资源目录: " + parent);
            }
            if (entry.getSize() > 8L * 1024L * 1024L) {
                throw new IOException("插件资源过大: " + name);
            }
            try (InputStream input = zip.getInputStream(entry);
                 OutputStream output = new FileOutputStream(target)) {
                byte[] buffer = new byte[32 * 1024];
                int read;
                while ((read = input.read(buffer)) != -1) {
                    output.write(buffer, 0, read);
                }
                output.flush();
            }
        }
    }

    private static void replaceTree(File source, File target) throws IOException {
        deleteTree(target);
        copyTree(source, target);
        deleteTree(source);
    }

    private static void copyTree(File source, File target) throws IOException {
        if (source.isDirectory()) {
            if (!ensureDirectory(target)) {
                throw new IOException("无法创建资源目录: " + target);
            }
            File[] children = source.listFiles();
            if (children != null) {
                for (File child : children) {
                    copyTree(child, new File(target, child.getName()));
                }
            }
            return;
        }
        File parent = target.getParentFile();
        if (parent != null && !ensureDirectory(parent)) {
            throw new IOException("无法创建资源目录: " + parent);
        }
        try (InputStream input = new FileInputStream(source);
             OutputStream output = new FileOutputStream(target)) {
            byte[] buffer = new byte[32 * 1024];
            int read;
            while ((read = input.read(buffer)) != -1) {
                output.write(buffer, 0, read);
            }
            output.flush();
        }
    }

    /** 先查插件 resources 目录，再退回应用自身的资源，供 ECJ/D8 读取。 */
    private static final class PluginDexClassLoader extends dalvik.system.DexClassLoader {
        private final File resources;

        PluginDexClassLoader(
                String dexPath,
                String optimizedDirectory,
                String librarySearchPath,
                ClassLoader parent,
                File resources) {
            super(dexPath, optimizedDirectory, librarySearchPath, parent);
            this.resources = resources;
        }

        @Override
        public InputStream getResourceAsStream(String name) {
            File file = resourceFile(name);
            if (file != null) {
                try {
                    return new FileInputStream(file);
                } catch (IOException ignored) {
                    // 文件不存在时继续走父加载器。
                }
            }
            return super.getResourceAsStream(name);
        }

        @Override
        public URL getResource(String name) {
            File file = resourceFile(name);
            if (file != null) {
                try {
                    return file.toURI().toURL();
                } catch (Exception ignored) {
                    // 退回父加载器。
                }
            }
            return super.getResource(name);
        }

        private File resourceFile(String name) {
            if (name == null || name.startsWith("/") || name.contains("..")) {
                return null;
            }
            File file = new File(resources, name);
            return file.isFile() ? file : null;
        }
    }

    private static boolean hasDexMagic(File file) throws IOException {
        try (FileInputStream input = new FileInputStream(file)) {
            byte[] magic = new byte[8];
            int read = input.read(magic);
            return read == 8 && magic[0] == 'd' && magic[1] == 'e'
                    && magic[2] == 'x' && magic[3] == '\n';
        }
    }

    private static void move(File source, File target) throws IOException {
        if (source.renameTo(target)) {
            return;
        }
        try (InputStream input = new FileInputStream(source);
             OutputStream output = new FileOutputStream(target)) {
            byte[] buffer = new byte[32 * 1024];
            int read;
            while ((read = input.read(buffer)) != -1) {
                output.write(buffer, 0, read);
            }
            output.flush();
        }
        deleteIfExists(source);
    }

    private static void deleteIfExists(File file) throws IOException {
        if (file.exists() && !file.delete()) {
            throw new IOException("无法删除旧插件文件: " + file.getName());
        }
    }

    private static void deleteTree(File file) {
        if (file == null || !file.exists()) {
            return;
        }
        File[] children = file.listFiles();
        if (children != null) {
            for (File child : children) {
                deleteTree(child);
            }
        }
        file.delete();
    }

    private static void writeText(File file, String text) throws IOException {
        try (OutputStream output = new FileOutputStream(file)) {
            output.write(text.getBytes("UTF-8"));
        }
    }

    private static String sha256(File file) throws IOException {
        try (InputStream input = new FileInputStream(file)) {
            MessageDigest digest;
            try {
                digest = MessageDigest.getInstance("SHA-256");
            } catch (Exception error) {
                throw new IOException("无法校验插件包", error);
            }
            byte[] buffer = new byte[32 * 1024];
            int read;
            while ((read = input.read(buffer)) != -1) {
                digest.update(buffer, 0, read);
            }
            byte[] bytes = digest.digest();
            StringBuilder builder = new StringBuilder(bytes.length * 2);
            for (byte value : bytes) {
                builder.append(String.format("%02x", value & 0xFF));
            }
            return builder.toString();
        }
    }
}
