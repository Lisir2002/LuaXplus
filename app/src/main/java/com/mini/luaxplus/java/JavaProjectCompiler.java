package com.mini.luaxplus.java;

import android.content.Context;
import android.content.res.AssetManager;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import com.mini.luaxplus.CompilerPlugin;
import com.mini.luaxplus.LogCore;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.lang.reflect.Method;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.List;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

/**
 * 手机内 Java 编译链：.java -> ECJ -> .class -> D8 -> classes.dex。
 *
 * ECJ、D8 与 android.jar 由“插件市场”按需安装的编译器插件提供，主 APK 不内置；
 * api-src 仍随主程序提供，只用于让 ECJ 认识 JavaHost / JavaScreen / LuaBridge 这几个
 * 宿主 API，运行时仍由父 ClassLoader 提供真实实现。
 */
public final class JavaProjectCompiler {

    private static final String TAG = "JavaCompiler";
    private static final String API_SOURCE_ASSET = "java/api-src";

    private JavaProjectCompiler() {
    }

    public static CompileResult compile(Context context, String sourceDir, String outputDir) {
        if (android.os.Build.VERSION.SDK_INT < 26) {
            return CompileResult.fail("手机内编译需要 Android 8.0 及以上系统");
        }
        if (context == null) {
            return CompileResult.fail("Context 为空");
        }
        if (sourceDir == null || outputDir == null) {
            return CompileResult.fail("源码目录或输出目录为空");
        }
        Context app = context.getApplicationContext();
        File sourceRoot = new File(sourceDir);
        File outputRoot = new File(outputDir);
        if (!sourceRoot.isDirectory()) {
            return CompileResult.fail("源码目录不存在: " + sourceRoot);
        }
        File classesDir = new File(outputRoot, "classes");
        File dexDir = new File(outputRoot, "dex");
        try {
            if (!CompilerPlugin.isInstalled(app)) {
                return CompileResult.fail("Java 编译器插件未安装，请到侧边栏“插件市场”下载安装");
            }
            File androidJar = CompilerPlugin.androidJar(app);
            ClassLoader compilerLoader = CompilerPlugin.classLoader(app);
            File apiSources = extractApiSources(app);
            cleanDirectory(classesDir);
            cleanDirectory(dexDir);

            List<File> sources = new ArrayList<>();
            collectJavaFiles(sourceRoot, sources);
            collectJavaFiles(apiSources, sources);
            if (sources.isEmpty()) {
                return CompileResult.fail("没有找到 .java 文件");
            }

            StringWriter compilerLog = new StringWriter();
            PrintWriter writer = new PrintWriter(compilerLog);
            String[] args = buildEcjArgs(androidJar, classesDir, sources);
            boolean compiled = compileWithEcj(compilerLoader, args, writer);
            writer.flush();
            String ecjOutput = compilerLog.toString();
            if (!compiled) {
                LogCore.w("JavaCompiler", "ECJ 编译失败: " + sourceRoot + "\n" + ecjOutput);
                return CompileResult.fail("ECJ 编译失败\n" + ecjOutput);
            }

            File classesJar = new File(outputRoot, "classes.jar");
            jarClasses(classesDir, classesJar);
            runD8(compilerLoader, classesJar, androidJar, dexDir);

            List<File> dexFiles = listDexFiles(dexDir);
            if (dexFiles.isEmpty()) {
                return CompileResult.fail("D8 没有生成 DEX\n" + ecjOutput);
            }
            String dexPath = joinPaths(dexFiles);
            String message = "编译成功，生成 " + dexFiles.size() + " 个 DEX";
            if (!ecjOutput.trim().isEmpty()) {
                message += "\n" + ecjOutput;
            }
            Log.i(TAG, message + "\n" + dexPath);
            return new CompileResult(true, message, dexPath, classesDir.getAbsolutePath());
        } catch (Throwable error) {
            Log.e(TAG, "Java 编译失败", error);
            LogCore.javaError("Java 编译异常: " + sourceRoot, error);
            return CompileResult.fail("编译异常: " + Log.getStackTraceString(error));
        }
    }

    /** 把 assets 中的示例工程复制到私有目录后编译。 */
    public static CompileResult compileAssetProject(Context context, String assetRoot, String projectName) {
        Context app = context.getApplicationContext();
        File sourceDir = new File(app.getFilesDir(), "java-projects/" + projectName + "/src");
        File outputDir = new File(app.getFilesDir(), "java-projects/" + projectName + "/build");
        try {
            cleanDirectory(sourceDir);
            copyAssetTree(app, assetRoot, sourceDir);
            return compile(app, sourceDir.getAbsolutePath(), outputDir.getAbsolutePath());
        } catch (Throwable error) {
            Log.e(TAG, "示例工程准备失败", error);
            LogCore.javaError("示例工程准备失败: " + assetRoot, error);
            return CompileResult.fail("示例工程准备失败: " + Log.getStackTraceString(error));
        }
    }

    /** 后台编译指定目录，完成后回主线程。 */
    public static void compileAsync(
            final Context context,
            final String sourceDir,
            final String outputDir,
            final JavaCompileCallback callback) {
        final Context app = context.getApplicationContext();
        new Thread(new Runnable() {
            @Override
            public void run() {
                final CompileResult result = compile(app, sourceDir, outputDir);
                new Handler(Looper.getMainLooper()).post(new Runnable() {
                    @Override
                    public void run() {
                        if (callback != null) {
                            callback.onResult(result);
                        }
                    }
                });
            }
        }, "java-compiler").start();
    }

    /** 后台编译 assets 中的示例工程，完成后回主线程。 */
    public static void compileAssetProjectAsync(
            final Context context,
            final String assetRoot,
            final String projectName,
            final JavaCompileCallback callback) {
        final Context app = context.getApplicationContext();
        new Thread(new Runnable() {
            @Override
            public void run() {
                final CompileResult result = compileAssetProject(app, assetRoot, projectName);
                new Handler(Looper.getMainLooper()).post(new Runnable() {
                    @Override
                    public void run() {
                        if (callback != null) {
                            callback.onResult(result);
                        }
                    }
                });
            }
        }, "java-compiler").start();
    }

    private static String[] buildEcjArgs(File androidJar, File classesDir, List<File> sources) {
        List<String> args = new ArrayList<>();
        args.add("-source");
        args.add("8");
        args.add("-target");
        args.add("8");
        args.add("-encoding");
        args.add("UTF-8");
        args.add("-proc:none");
        args.add("-nowarn");
        args.add("-bootclasspath");
        args.add(androidJar.getAbsolutePath());
        args.add("-classpath");
        args.add(androidJar.getAbsolutePath());
        args.add("-d");
        args.add(classesDir.getAbsolutePath());
        for (File source : sources) {
            args.add(source.getAbsolutePath());
        }
        return args.toArray(new String[0]);
    }

    private static boolean compileWithEcj(
            ClassLoader loader, String[] args, PrintWriter writer) throws Exception {
        Thread current = Thread.currentThread();
        ClassLoader previous = current.getContextClassLoader();
        try {
            current.setContextClassLoader(loader);
            Class<?> mainClass = Class.forName(
                    "org.eclipse.jdt.internal.compiler.batch.Main", true, loader);
            Class<?> progressClass = Class.forName(
                    "org.eclipse.jdt.core.compiler.CompilationProgress", true, loader);
            Method compile = mainClass.getMethod(
                    "compile", String[].class, PrintWriter.class, PrintWriter.class, progressClass);
            Object result = compile.invoke(null, new Object[]{args, writer, writer, null});
            return Boolean.TRUE.equals(result);
        } finally {
            current.setContextClassLoader(previous);
        }
    }

    /**
     * 用插件里的 D8 生成 DEX。这里全部走反射，源码编译阶段不再依赖 D8 JAR，
     * 插件未安装时主程序也能正常构建。
     */
    private static void runD8(
            ClassLoader loader, File classesJar, File androidJar, File dexDir) throws Exception {
        Thread current = Thread.currentThread();
        ClassLoader previous = current.getContextClassLoader();
        try {
            current.setContextClassLoader(loader);
            Class<?> d8Class = Class.forName("com.android.tools.r8.D8", true, loader);
            Class<?> commandClass = Class.forName("com.android.tools.r8.D8Command", true, loader);
            Class<?> builderClass = Class.forName("com.android.tools.r8.D8Command$Builder", true, loader);
            Class<?> outputModeClass = Class.forName("com.android.tools.r8.OutputMode", true, loader);

            Object builder = commandClass.getMethod("builder").invoke(null);
            builderClass.getMethod("addProgramFiles", Path[].class)
                    .invoke(builder, new Object[]{new Path[]{classesJar.toPath()}});
            builderClass.getMethod("addLibraryFiles", Path[].class)
                    .invoke(builder, new Object[]{new Path[]{androidJar.toPath()}});
            builderClass.getMethod("setMinApiLevel", int.class).invoke(builder, 21);

            Object dexIndexed = null;
            Object[] modes = outputModeClass.getEnumConstants();
            if (modes != null) {
                for (Object mode : modes) {
                    if ("DexIndexed".equals(((Enum<?>) mode).name())) {
                        dexIndexed = mode;
                        break;
                    }
                }
            }
            if (dexIndexed == null) {
                throw new IllegalStateException("插件中的 D8 缺少 DexIndexed 输出模式");
            }
            builderClass.getMethod("setOutput", Path.class, outputModeClass)
                    .invoke(builder, dexDir.toPath(), dexIndexed);
            Object command = builderClass.getMethod("build").invoke(builder);
            d8Class.getMethod("run", commandClass).invoke(null, command);
        } finally {
            current.setContextClassLoader(previous);
        }
    }

    private static File extractApiSources(Context context) throws IOException {
        File target = new File(context.getFilesDir(), "java-build/api-src");
        cleanDirectory(target);
        copyAssetTree(context, API_SOURCE_ASSET, target);
        return target;
    }

    private static void collectJavaFiles(File directory, List<File> result) {
        File[] files = directory.listFiles();
        if (files == null) {
            return;
        }
        Arrays.sort(files, new Comparator<File>() {
            @Override
            public int compare(File left, File right) {
                return left.getName().compareToIgnoreCase(right.getName());
            }
        });
        for (File file : files) {
            if (file.isDirectory()) {
                collectJavaFiles(file, result);
            } else if (file.getName().endsWith(".java")) {
                result.add(file);
            }
        }
    }

    private static void jarClasses(File classesDir, File jarFile) throws IOException {
        try (ZipOutputStream output = new ZipOutputStream(new FileOutputStream(jarFile))) {
            addClassEntries(classesDir, classesDir, output);
        }
    }

    private static void addClassEntries(File root, File current, ZipOutputStream output) throws IOException {
        File[] files = current.listFiles();
        if (files == null) {
            return;
        }
        for (File file : files) {
            if (file.isDirectory()) {
                addClassEntries(root, file, output);
            } else if (file.getName().endsWith(".class")) {
                String name = root.toURI().relativize(file.toURI()).getPath();
                output.putNextEntry(new ZipEntry(name));
                try (FileInputStream input = new FileInputStream(file)) {
                    byte[] buffer = new byte[16 * 1024];
                    int read;
                    while ((read = input.read(buffer)) != -1) {
                        output.write(buffer, 0, read);
                    }
                }
                output.closeEntry();
            }
        }
    }

    private static List<File> listDexFiles(File dexDir) {
        List<File> dexFiles = new ArrayList<>();
        File[] files = dexDir.listFiles();
        if (files != null) {
            for (File file : files) {
                if (file.isFile() && file.getName().endsWith(".dex")) {
                    dexFiles.add(file);
                }
            }
        }
        java.util.Collections.sort(dexFiles, new Comparator<File>() {
            @Override
            public int compare(File left, File right) {
                return left.getName().compareToIgnoreCase(right.getName());
            }
        });
        return dexFiles;
    }

    private static String joinPaths(List<File> files) {
        StringBuilder builder = new StringBuilder();
        for (File file : files) {
            if (builder.length() > 0) {
                builder.append(File.pathSeparator);
            }
            builder.append(file.getAbsolutePath());
        }
        return builder.toString();
    }

    private static void copyAssetTree(Context context, String assetPath, File targetDir) throws IOException {
        AssetManager assets = context.getAssets();
        String[] children;
        try {
            children = assets.list(assetPath);
        } catch (IOException notDirectory) {
            children = null;
        }
        if (children == null || children.length == 0) {
            File parent = targetDir.getParentFile();
            if (parent != null && !parent.exists() && !parent.mkdirs()) {
                throw new IOException("无法创建目录: " + parent);
            }
            copyAsset(assets, assetPath, targetDir);
            return;
        }
        if (!targetDir.exists() && !targetDir.mkdirs()) {
            throw new IOException("无法创建目录: " + targetDir);
        }
        for (String child : children) {
            String childAsset = assetPath + "/" + child;
            File childTarget = new File(targetDir, child);
            if (childTarget.exists() && childTarget.isDirectory()) {
                copyAssetTree(context, childAsset, childTarget);
            } else if (isAssetDirectory(assets, childAsset)) {
                copyAssetTree(context, childAsset, childTarget);
            } else {
                copyAsset(assets, childAsset, childTarget);
            }
        }
    }

    private static boolean isAssetDirectory(AssetManager assets, String assetPath) {
        try {
            String[] children = assets.list(assetPath);
            return children != null && children.length > 0;
        } catch (IOException ignored) {
            return false;
        }
    }

    private static void copyAsset(AssetManager assets, String assetPath, File target) throws IOException {
        try (InputStream input = assets.open(assetPath);
             FileOutputStream output = new FileOutputStream(target)) {
            byte[] buffer = new byte[16 * 1024];
            int read;
            while ((read = input.read(buffer)) != -1) {
                output.write(buffer, 0, read);
            }
            output.flush();
        }
    }

    private static void cleanDirectory(File directory) throws IOException {
        if (!directory.exists()) {
            if (!directory.mkdirs() && !directory.isDirectory()) {
                throw new IOException("无法创建目录: " + directory);
            }
            return;
        }
        File[] files = directory.listFiles();
        if (files == null) {
            return;
        }
        for (File file : files) {
            if (file.isDirectory()) {
                cleanDirectory(file);
            }
            if (!file.delete() && file.exists()) {
                throw new IOException("无法清理旧文件: " + file);
            }
        }
    }

    public static final class CompileResult {
        public final boolean success;
        public final String message;
        public final String dexPath;
        public final String classDir;

        CompileResult(boolean success, String message, String dexPath, String classDir) {
            this.success = success;
            this.message = message;
            this.dexPath = dexPath;
            this.classDir = classDir;
        }

        static CompileResult fail(String message) {
            Log.e(TAG, message);
            return new CompileResult(false, message, null, null);
        }
    }
}
