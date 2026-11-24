package com.mini.luaxplus.java;

import android.app.Activity;
import android.content.Context;
import android.content.res.Resources;

/** Java 页面可访问的宿主能力。 */
public interface JavaHost {

    Activity activity();

    Context context();

    Resources resources();

    /** 工程目录；独立运行时可能为 null。 */
    String projectDir();

    /** 与宿主关联的 Lua 桥；纯 Java 页面启动时为 null。 */
    LuaBridge lua();

    /** 读取启动参数；优先按 key 查找 Intent，没有时返回 Lua 传入的单一参数。 */
    String argument(String key);

    void runOnUiThread(Runnable action);

    void finish();

    void setScreenTitle(String title);
}
