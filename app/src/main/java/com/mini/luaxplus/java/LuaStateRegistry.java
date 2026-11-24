package com.mini.luaxplus.java;

import com.luajava.LuaState;

import java.lang.ref.WeakReference;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

/** 在 LuaActivity 和 JavaHostActivity 之间传递同一个 LuaState。 */
public final class LuaStateRegistry {

    private static final Map<String, WeakReference<LuaState>> STATES = new ConcurrentHashMap<>();
    private static final Map<String, LuaState> PINNED = new ConcurrentHashMap<>();
    private static final AtomicInteger NEXT_TOKEN = new AtomicInteger(1);

    private LuaStateRegistry() {
    }

    public static String attach(LuaState state) {
        if (state == null) {
            return null;
        }
        String token = "lua-" + NEXT_TOKEN.getAndIncrement();
        STATES.put(token, new WeakReference<>(state));
        return token;
    }

    /** 由 Java 入口创建的 LuaState 没有 Activity 持有，需要额外固定到宿主关闭。 */
    public static String attachStrong(LuaState state) {
        String token = attach(state);
        if (token != null) {
            PINNED.put(token, state);
        }
        return token;
    }

    public static LuaState get(String token) {
        if (token == null) {
            return null;
        }
        WeakReference<LuaState> reference = STATES.get(token);
        return reference == null ? null : reference.get();
    }

    public static void release(String token) {
        if (token != null) {
            STATES.remove(token);
            PINNED.remove(token);
        }
    }
}
