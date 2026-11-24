package com.mini.luaxplus;

import android.content.Context;
import android.content.pm.PackageInfo;
import android.content.res.AssetManager;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;

/**
 * 脚本铺设：运行时从应用私有目录读取 main.lua，因此首次启动需要把 assets 内的
 * 脚本与资源复制到私有目录，版本变化后重新铺设。
 */
public final class AssetBootstrap {

    private static final String TAG = "Bootstrap";
    private static final String MARKER = ".luaxplus_bootstrap";
    private static final String[] SKIP_NAMES = {"keys"};
    private static final String[] SKIP_SUFFIX = {".dex"};

    private AssetBootstrap() {
    }

    public static boolean ensure(Context context) {
        if (context == null) {
            return false;
        }
        File target = context.getFilesDir();
        File marker = new File(target, MARKER);
        File entry = new File(target, "main.lua");
        String stamp = stamp(context);
        if (entry.isFile() && marker.isFile() && readMarker(marker).startsWith(stamp)) {
            LogCore.i(TAG, "脚本已就绪 " + stamp + "，跳过铺设");
            return true;
        }
        LogCore.i(TAG, "开始铺设脚本 " + stamp + " 旧标记=" + readMarker(marker));
        long start = System.currentTimeMillis();
        int[] files = new int[1];
        long[] bytes = new long[1];
        boolean ok;
        try {
            // 资源目录只作为内置示例的铺设源，版本更新时先清掉旧文件，
            // 避免已删除的 init.lua、main.lua 继续被复制到示例目录。
            deleteTree(new File(target, "examples"));
            copyDir(context.getAssets(), "", target, files, bytes);
            // 打包组件按无扩展名加载，需把 mao.dex、sign.dex 另存为 mao、sign
            copyDex(context.getAssets(), "mao.dex", new File(target, "mao"), bytes);
            copyDex(context.getAssets(), "sign.dex", new File(target, "sign"), bytes);
            // 用户脚本运行时按 app_lua 目录查找 import、loadlayout 等基础模块
            File luaHome = context.getDir("lua", Context.MODE_PRIVATE);
            int[] luaFiles = new int[1];
            long[] luaBytes = new long[1];
            copyDir(context.getAssets(), "lua", luaHome, luaFiles, luaBytes);
            LogCore.i(TAG, "基础模块铺设完成 " + luaHome.getAbsolutePath()
                    + " 文件=" + luaFiles[0] + " 字节=" + luaBytes[0]);
            ok = new File(target, "main.lua").isFile();
            writeMarker(marker, stamp + "|" + files[0] + "|" + start);
        } catch (Exception exception) {
            LogCore.e(TAG, "脚本铺设失败: " + exception);
            LogCore.luaError("脚本铺设失败", exception.toString());
            return false;
        }
        long cost = System.currentTimeMillis() - start;
        LogCore.i(TAG, "脚本铺设完成 文件=" + files[0] + " 字节=" + bytes[0]
                + " 耗时=" + cost + "ms 结果=" + ok);
        return ok;
    }

    private static void copyDir(AssetManager assets, String path, File target,
                               int[] files, long[] bytes) throws IOException {
        String[] children = assets.list(path);
        if (children == null) {
            return;
        }
        for (String child : children) {
            if (skip(child)) {
                continue;
            }
            String assetPath = path.isEmpty() ? child : path + "/" + child;
            String[] sub = assets.list(assetPath);
            File destination = new File(target, child);
            if (sub != null && sub.length > 0) {
                if (!destination.isDirectory() && !destination.mkdirs()) {
                    LogCore.w(TAG, "创建目录失败: " + destination);
                    continue;
                }
                copyDir(assets, assetPath, destination, files, bytes);
            } else {
                copyFile(assets, assetPath, destination, bytes);
                files[0]++;
            }
        }
    }

    /** 把 assets 内的 dex 复制成运行时要求的无扩展名文件 */
    private static void copyDex(AssetManager assets, String assetPath, File destination,
                                long[] bytes) throws IOException {
        copyFile(assets, assetPath, destination, bytes);
        LogCore.i(TAG, "打包组件铺设 " + assetPath + " -> " + destination.getName()
                + " 大小=" + destination.length());
    }

    private static void copyFile(AssetManager assets, String assetPath, File destination,
                                 long[] bytes) throws IOException {
        File parent = destination.getParentFile();
        if (parent != null && !parent.exists() && !parent.mkdirs()) {
            LogCore.w(TAG, "创建目标目录失败: " + parent);
        }
        InputStream inputStream = null;
        OutputStream outputStream = null;
        try {
            inputStream = assets.open(assetPath);
            outputStream = new FileOutputStream(destination);
            byte[] buffer = new byte[8192];
            int length;
            while ((length = inputStream.read(buffer)) > 0) {
                outputStream.write(buffer, 0, length);
                bytes[0] += length;
            }
            outputStream.flush();
        } catch (IOException exception) {
            LogCore.w(TAG, "复制失败 " + assetPath + ": " + exception);
        } finally {
            closeQuietly(inputStream);
            closeQuietly(outputStream);
        }
    }

    /** 递归删除内置资源的旧缓存，不跟随目录外的符号链接。 */
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
        if (!file.delete()) {
            LogCore.w(TAG, "删除旧资源失败: " + file.getAbsolutePath());
        }
    }

    private static boolean skip(String name) {
        for (String skipName : SKIP_NAMES) {
            if (skipName.equals(name)) {
                return true;
            }
        }
        for (String suffix : SKIP_SUFFIX) {
            if (name.endsWith(suffix)) {
                return true;
            }
        }
        return false;
    }

    private static String readMarker(File marker) {
        try {
            java.io.BufferedReader reader = new java.io.BufferedReader(
                    new java.io.InputStreamReader(new java.io.FileInputStream(marker), "UTF-8"));
            try {
                String line = reader.readLine();
                return line == null ? "" : line;
            } finally {
                closeQuietly(reader);
            }
        } catch (IOException exception) {
            return "";
        }
    }

    private static void writeMarker(File marker, String content) {
        FileOutputStream outputStream = null;
        try {
            outputStream = new FileOutputStream(marker);
            outputStream.write(content.getBytes("UTF-8"));
            outputStream.flush();
        } catch (IOException exception) {
            LogCore.w(TAG, "写入铺设标记失败: " + exception);
        } finally {
            closeQuietly(outputStream);
        }
    }

    /**
     * 铺设指纹：版本名 + 安装时间。同版本号重装也会刷新脚本，避免残留旧文件。
     */
    private static String stamp(Context context) {
        try {
            PackageInfo info = context.getPackageManager()
                    .getPackageInfo(context.getPackageName(), 0);
            String version = info.versionName == null ? "" : info.versionName;
            return version + "|" + info.lastUpdateTime;
        } catch (Exception exception) {
            return "";
        }
    }

    private static void closeQuietly(java.io.Closeable closeable) {
        if (closeable != null) {
            try {
                closeable.close();
            } catch (IOException ignored) {
                // 关闭失败不影响流程
            }
        }
    }
}
