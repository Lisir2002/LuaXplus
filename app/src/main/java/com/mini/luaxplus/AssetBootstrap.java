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
        String version = versionName(context);
        if (entry.isFile() && marker.isFile() && readMarker(marker).startsWith(version)) {
            LogCore.i(TAG, "脚本已就绪，版本 " + version + "，跳过铺设");
            return true;
        }
        long start = System.currentTimeMillis();
        int[] files = new int[1];
        long[] bytes = new long[1];
        boolean ok;
        try {
            copyDir(context.getAssets(), "", target, files, bytes);
            ok = new File(target, "main.lua").isFile();
            writeMarker(marker, version + "|" + files[0] + "|" + start);
        } catch (Exception exception) {
            LogCore.e(TAG, "脚本铺设失败: " + exception);
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

    private static String versionName(Context context) {
        try {
            PackageInfo info = context.getPackageManager()
                    .getPackageInfo(context.getPackageName(), 0);
            return info.versionName == null ? "" : info.versionName;
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
