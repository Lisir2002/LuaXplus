package com.mini.luaxplus.java;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import com.luajava.LuaException;
import com.luajava.LuaObject;
import com.luajava.LuaState;

/**
 * Java 调用 Lua 的统一入口。
 *
 * LuaState 不是线程安全的：同步调用直接在调用线程执行，后台线程应使用 post()
 * 回到主线程。桥本身不持有 LuaState 的生命周期，状态由创建它的宿主负责关闭。
 */
public final class LuaBridge {

    private static final String TAG = "JavaLuaBridge";

    private final LuaState state;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    public LuaBridge(LuaState state) {
        if (state == null) {
            throw new IllegalArgumentException("LuaState == null");
        }
        this.state = state;
    }

    public boolean hasFunction(String name) {
        synchronized (state) {
            LuaObject function = state.getLuaObject(name);
            return function != null && !function.isNil() && function.isFunction();
        }
    }

    /** 同步调用 Lua 全局函数，返回最后一个返回值。 */
    public Object call(String name, Object... args) throws LuaException {
        synchronized (state) {
            LuaObject function = state.getLuaObject(name);
            if (function == null || function.isNil()) {
                return null;
            }
            return function.call(args);
        }
    }

    /** 后台线程安全调用：切回主线程再执行 Lua。 */
    public void post(final String name, final Object... args) {
        mainHandler.post(new Runnable() {
            @Override
            public void run() {
                try {
                    call(name, args);
                } catch (Throwable error) {
                    Log.e(TAG, "Lua 回调失败: " + name, error);
                }
            }
        });
    }

    /** 执行一段 Lua 代码，返回最后留在栈上的值。 */
    public Object eval(String code) throws LuaException {
        synchronized (state) {
            int status = state.LdoString(code == null ? "" : code);
            if (status != 0) {
                throw new LuaException("Lua eval failed: " + status);
            }
            LuaObject result = state.getLuaObject(-1);
            state.pop(1);
            if (result == null || result.isNil()) {
                return null;
            }
            return result.getObject();
        }
    }
}
