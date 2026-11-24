package com.mini.luaxplus.java;

import android.app.Activity;
import android.content.Context;
import android.widget.Toast;

import com.luajava.LuaState;
import com.luajava.LuaStateFactory;
import com.mini.luaxplus.LogCore;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.Properties;

/**
 * 成品包里的 Java 工程启动入口。
 *
 * 打包后的 Java 工程没有 init.lua / main.lua，启动页从这里读取
 * assets/project.properties，加载 assets/java 下的已编译 DEX，
 * 直接把 JavaScreen 交给 JavaHostActivity 显示。
 */
public final class JavaPackagedEntry {

    private static final String DESCRIPTOR = "project.properties";

    private JavaPackagedEntry() {
    }

    public static boolean isJavaPackage(Context context) {
        if (context == null || LogCore.OWNER_PACKAGE.equals(context.getPackageName())) {
            return false;
        }
        Properties properties = read(context);
        return properties != null && "java".equalsIgnoreCase(properties.getProperty("type", ""));
    }

    public static void start(Activity activity) {
        if (activity == null) {
            return;
        }
        try {
            Properties properties = read(activity);
            String screen = trim(properties == null ? null : properties.getProperty("screen"));
            if (screen == null) {
                throw new IllegalStateException("assets/" + DESCRIPTOR + " 缺少 screen");
            }
            String lua = trim(properties.getProperty("lua"));
            String argument = trim(properties.getProperty("argument"));
            String token = lua == null ? null : attachLua(activity, lua);
            JavaRuntime.startWithDex(activity, screen, token, null, "assets:/", argument);
            activity.finish();
        } catch (Throwable error) {
            LogCore.javaError("成品 Java 工程启动失败", error);
            Toast.makeText(activity, "Java 工程启动失败：" + error, Toast.LENGTH_LONG).show();
            activity.finish();
        }
    }

    private static Properties read(Context context) {
        try (InputStream input = context.getAssets().open(DESCRIPTOR);
             InputStreamReader reader = new InputStreamReader(input, StandardCharsets.UTF_8)) {
            Properties properties = new Properties();
            properties.load(reader);
            return properties;
        } catch (Throwable error) {
            return null;
        }
    }

    private static String attachLua(Activity activity, String scriptName) throws Exception {
        byte[] script = assetBytes(activity, scriptName);
        LuaState state = LuaStateFactory.newLuaState();
        try {
            state.openLibs();
            // 打包器会把 Lua 脚本编译成二进制块；必须按原始字节加载，
            // 不能先转成 UTF-8 字符串，否则二进制头会被破坏。
            int status = state.LloadBuffer(script, scriptName);
            if (status != 0) {
                throw new IllegalStateException("Lua 脚本加载失败: " + state.toString(-1));
            }
            // LloadBuffer 只把脚本压栈，必须再执行一次才会注册 getLuaMessage / onJavaMessage 等全局函数。
            int run = state.pcall(0, 0, 0);
            if (run != 0) {
                throw new IllegalStateException("Lua 脚本执行失败: " + state.toString(-1));
            }
            return LuaStateRegistry.attachStrong(state);
        } catch (Exception error) {
            state.close();
            throw error;
        }
    }

    private static byte[] assetBytes(Context context, String name) throws Exception {
        try (InputStream input = context.getAssets().open(name)) {
            ByteArrayOutputStream output = new ByteArrayOutputStream();
            byte[] buffer = new byte[8192];
            int read;
            while ((read = input.read(buffer)) != -1) {
                output.write(buffer, 0, read);
            }
            return output.toByteArray();
        }
    }

    private static String trim(String value) {
        if (value == null) {
            return null;
        }
        String text = value.trim();
        return text.isEmpty() ? null : text;
    }
}
