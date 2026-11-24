package com.mini.luaxplus.java;

import android.app.Activity;
import android.content.Context;
import android.content.res.Resources;

public interface JavaHost {
    Activity activity();

    Context context();

    Resources resources();

    String projectDir();

    LuaBridge lua();

    /** 读取启动参数；优先按 key 查找 Intent，没有时返回 Lua 传入的单一参数。 */
    String argument(String key);

    void runOnUiThread(Runnable action);

    void finish();

    void setScreenTitle(String title);
}
