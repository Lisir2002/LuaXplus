package com.mini.luaxplus.java;

import android.content.Context;
import android.content.res.AssetManager;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;

import dalvik.system.DexClassLoader;

/** 把 assets/java/classes.dex 复制到可写目录并加载。 */
public final class JavaDexLoader {

    private static final String ASSET_DEX = "java/classes.dex";

    private JavaDexLoader() {
    }

    public static ClassLoader load(Context context) throws IOException {
        File dir = new File(context.getFilesDir(), "java");
        AssetManager assets = context.getAssets();
        List<String> dexPaths = new ArrayList<>();
        for (int index = 1; index <= 20; index++) {
            String assetName = index == 1 ? ASSET_DEX : "java/classes" + index + ".dex";
            try {
                assets.open(assetName).close();
            } catch (IOException missing) {
                if (index == 1) {
                    return null;
                }
                break;
            }
            File target = new File(dir, "classes" + (index == 1 ? "" : index) + ".dex");
            if (!dir.exists() && !dir.mkdirs()) {
                throw new IOException("无法创建 Java DEX 目录: " + dir);
            }
            // 覆盖安装或重复启动时，旧 DEX 可能仍存在；先恢复可写再覆盖，避免首次启动后
            // 再次进入页面时因只读文件无法写入而加载失败。
            if (target.exists() && !target.setWritable(true) && !target.delete()) {
                throw new IOException("DEX 文件不可写且无法删除: " + target);
            }
            copyAsset(assets, assetName, target);
            dexPaths.add(target.getAbsolutePath());
        }
        if (dexPaths.isEmpty()) {
            return null;
        }
        StringBuilder path = new StringBuilder();
        for (String dexPath : dexPaths) {
            if (path.length() > 0) {
                path.append(File.pathSeparator);
            }
            path.append(dexPath);
        }
        return fromPath(context, path.toString());
    }

    /** 加载编译产物；path 可以是单个 DEX，也可以是多个 DEX 的路径列表。 */
    public static ClassLoader fromPath(Context context, String dexPath) throws IOException {
        if (dexPath == null || dexPath.trim().isEmpty()) {
            return null;
        }
        String[] paths = dexPath.split(File.pathSeparator);
        for (String path : paths) {
            if (!new File(path).isFile()) {
                throw new IOException("DEX 不存在: " + path);
            }
        }
        return new DexClassLoader(
                dexPath,
                context.getCodeCacheDir().getAbsolutePath(),
                null,
                context.getClassLoader());
    }

    private static void copyAsset(AssetManager assets, String name, File target) throws IOException {
        try (InputStream input = assets.open(name);
             FileOutputStream output = new FileOutputStream(target)) {
            byte[] buffer = new byte[8192];
            int read;
            while ((read = input.read(buffer)) != -1) {
                output.write(buffer, 0, read);
            }
            output.flush();
        }
    }
}
