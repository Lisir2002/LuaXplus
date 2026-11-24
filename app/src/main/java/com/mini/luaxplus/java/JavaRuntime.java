package com.mini.luaxplus.java;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;

import com.luajava.LuaState;
import com.mini.luaxplus.LogCore;

import java.lang.reflect.Method;

/** Java 页面的启动入口，Lua 和 Java 都可以调用。 */
public final class JavaRuntime {

    public static final String EXTRA_SCREEN = "java_screen";
    public static final String EXTRA_LUA_TOKEN = "java_lua_token";
    public static final String EXTRA_PROJECT_DIR = "java_project_dir";
    public static final String EXTRA_DEX_PATH = "java_dex_path";
    public static final String EXTRA_ARGUMENT = "java_argument";

    private JavaRuntime() {
    }

    /** 把当前 LuaState 登记为一个短 token，随后交给 JavaHostActivity。 */
    public static String attachLuaState(LuaState state) {
        return LuaStateRegistry.attach(state);
    }

    public static void releaseLuaState(String token) {
        LuaStateRegistry.release(token);
    }

    public static void start(Activity activity, String screenClass) {
        start(activity, screenClass, null, null);
    }

    public static void start(Activity activity, String screenClass, String luaToken) {
        start(activity, screenClass, luaToken, null);
    }

    public static void start(Activity activity, String screenClass, String luaToken, String projectDir) {
        startWithDex(activity, screenClass, luaToken, null, projectDir, null);
    }

    public static void startWithDex(
            Activity activity,
            String screenClass,
            String luaToken,
            String dexPath,
            String projectDir) {
        startWithDex(activity, screenClass, luaToken, dexPath, projectDir, null);
    }

    public static void startWithDex(
            Activity activity,
            String screenClass,
            String luaToken,
            String dexPath,
            String projectDir,
            String argument) {
        Intent intent = new Intent(activity, JavaHostActivity.class);
        intent.putExtra(EXTRA_SCREEN, screenClass);
        if (luaToken != null) {
            intent.putExtra(EXTRA_LUA_TOKEN, luaToken);
        }
        if (dexPath != null) {
            intent.putExtra(EXTRA_DEX_PATH, dexPath);
        }
        if (projectDir != null) {
            intent.putExtra(EXTRA_PROJECT_DIR, projectDir);
        }
        if (argument != null) {
            intent.putExtra(EXTRA_ARGUMENT, argument);
        }
        activity.startActivity(intent);
    }

    /**
     * 从 Lua 调用动态 DEX 里的 Java 静态方法。
     * 只做单参数字符串调用，避免 Lua 变参和重载解析把示例弄复杂。
     */
    public static String callStaticString(
            Context context,
            String dexPath,
            String className,
            String methodName,
            String argument) throws Exception {
        try {
            ClassLoader loader = JavaDexLoader.fromPath(context, dexPath);
            Class<?> target = Class.forName(className, true, loader);
            Method method = target.getMethod(methodName, String.class);
            Object result = method.invoke(null, argument);
            return result == null ? null : String.valueOf(result);
        } catch (Exception error) {
            LogCore.javaError("Java 静态方法调用失败: " + className + "." + methodName, error);
            throw error;
        }
    }

    public static void start(Context context, String screenClass) {
        Intent intent = new Intent(context, JavaHostActivity.class);
        intent.putExtra(EXTRA_SCREEN, screenClass);
        if (context instanceof Activity) {
            context.startActivity(intent);
        } else {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
        }
    }

    /** 供页面在 onCreate 中读取启动参数。 */
    public static Bundle extras(JavaHost host) {
        if (host == null || !(host.activity() instanceof JavaHostActivity)) {
            return Bundle.EMPTY;
        }
        Intent intent = ((JavaHostActivity) host.activity()).getIntent();
        return intent == null ? Bundle.EMPTY : intent.getExtras();
    }
}
