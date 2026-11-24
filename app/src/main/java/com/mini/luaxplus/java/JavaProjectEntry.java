package com.mini.luaxplus.java;

import android.app.Activity;
import android.app.AlertDialog;
import android.os.Build;
import android.widget.Toast;

import com.luajava.LuaState;
import com.luajava.LuaStateFactory;
import com.mini.luaxplus.LogCore;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.Properties;

/**
 * Java 工程入口：读取 project.properties，自动编译工程并直接打开 Java 页面。
 * 工程可以只有 Java 源码和描述文件，不依赖 init.lua / main.lua。
 */
public final class JavaProjectEntry {

    private static final String DESCRIPTOR = "project.properties";

    private JavaProjectEntry() {
    }

    public static void open(final Activity activity, final String projectDir) {
        if (activity == null || projectDir == null) {
            return;
        }
        final File root = new File(projectDir);
        final Info info;
        try {
            info = read(root);
        } catch (Exception error) {
            LogCore.javaError("Java 工程描述读取失败: " + projectDir, error);
            showError(activity, "Java 工程描述读取失败", error.toString());
            return;
        }
        if (!"java".equalsIgnoreCase(info.type)) {
            showError(activity, "不是 Java 工程", "project.properties 的 type 必须是 java");
            return;
        }
        if (info.screen == null || info.screen.trim().isEmpty()) {
            showError(activity, "Java 工程缺少页面类", "project.properties 需要 screen 字段");
            return;
        }
        if (Build.VERSION.SDK_INT < 26) {
            showError(activity, "无法编译 Java 工程", "手机内编译需要 Android 8.0 及以上系统");
            return;
        }
        final String outputDir = new File(root, ".build/java").getAbsolutePath();
        Toast.makeText(activity, "正在编译 " + info.name + "…", Toast.LENGTH_SHORT).show();
        JavaProjectCompiler.compileAsync(activity, root.getAbsolutePath(), outputDir,
                new JavaCompileCallback() {
                    @Override
                    public void onResult(JavaProjectCompiler.CompileResult result) {
                        if (!result.success) {
                            showError(activity, "Java 编译失败", result.message);
                            return;
                        }
                        start(activity, root, info, result.dexPath);
                    }
                });
    }

    private static void start(Activity activity, File root, Info info, String dexPath) {
        String token = null;
        try {
            if (info.lua != null && !info.lua.trim().isEmpty()) {
                token = attachLua(root, info.lua);
            }
            JavaRuntime.startWithDex(
                    activity,
                    info.screen,
                    token,
                    dexPath,
                    root.getAbsolutePath(),
                    info.argument
            );
        } catch (Exception error) {
            if (token != null) {
                LuaStateRegistry.release(token);
            }
            LogCore.javaError("Java 工程页面启动失败: " + info.screen, error);
            showError(activity, "Java 页面启动失败", error.toString());
        }
    }

    private static String attachLua(File root, String scriptName) throws Exception {
        File script = new File(root, scriptName);
        String rootPath = root.getCanonicalPath();
        String scriptPath = script.getCanonicalPath();
        if (!scriptPath.startsWith(rootPath + File.separator)) {
            throw new IllegalArgumentException("Lua 脚本必须在工程目录内: " + scriptName);
        }
        if (!script.isFile()) {
            throw new IllegalArgumentException("Lua 脚本不存在: " + scriptName);
        }
        LuaState state = LuaStateFactory.newLuaState();
        try {
            state.openLibs();
            int status = state.LdoString(readText(script));
            if (status != 0) {
                throw new IllegalStateException("Lua 脚本加载失败: " + state.toString(-1));
            }
            return LuaStateRegistry.attachStrong(state);
        } catch (Exception error) {
            state.close();
            throw error;
        }
    }

    private static Info read(File root) throws Exception {
        File descriptor = new File(root, DESCRIPTOR);
        if (!descriptor.isFile()) {
            throw new IllegalArgumentException("缺少 " + DESCRIPTOR);
        }
        Properties properties = new Properties();
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(
                new FileInputStream(descriptor), StandardCharsets.UTF_8))) {
            properties.load(reader);
        }
        Info info = new Info();
        info.type = properties.getProperty("type", "java");
        info.name = properties.getProperty("name", root.getName());
        info.screen = properties.getProperty("screen");
        info.lua = properties.getProperty("lua");
        info.argument = properties.getProperty("argument");
        return info;
    }

    private static String readText(File file) throws Exception {
        StringBuilder builder = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(
                new FileInputStream(file), StandardCharsets.UTF_8))) {
            String line;
            while ((line = reader.readLine()) != null) {
                builder.append(line).append('\n');
            }
        }
        return builder.toString();
    }

    private static void showError(final Activity activity, final String title, final String message) {
        if (activity == null || activity.isFinishing()) {
            return;
        }
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    new AlertDialog.Builder(activity)
                            .setTitle(title)
                            .setMessage(message == null ? "未知错误" : message)
                            .setPositiveButton("知道了", null)
                            .show();
                } catch (Throwable error) {
                    Toast.makeText(activity, title, Toast.LENGTH_SHORT).show();
                }
            }
        });
    }

    private static final class Info {
        String type;
        String name;
        String screen;
        String lua;
        String argument;
    }
}
