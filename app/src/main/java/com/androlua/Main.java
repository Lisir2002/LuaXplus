package com.androlua;

import android.content.Intent;
import android.os.Bundle;

import com.mini.luaxplus.BootTrace;

/** 主界面入口：保留原有 Lua 生命周期，增加启动阶段轨迹并去掉第三方统计初始化。 */
public class Main extends LuaActivity {

    @Override
    public String getLuaDir() {
        return getLocalDir();
    }

    @Override
    public String getLuaPath() {
        BootTrace.mark("Main.getLuaPath enter");
        initMain();
        String path = getLocalDir() + "/main.lua";
        BootTrace.mark("Main.getLuaPath done path=" + path);
        return path;
    }

    @Override
    public void initMain() {
        BootTrace.mark("Main.initMain enter");
        super.initMain();
        BootTrace.mark("Main.initMain done");
    }

    @Override
    public Object doFile(String path, Object[] args) {
        BootTrace.mark("Main.doFile enter path=" + path);
        try {
            Object result = super.doFile(path, args);
            BootTrace.mark("Main.doFile done path=" + path);
            return result;
        } catch (Throwable throwable) {
            BootTrace.crash(throwable, Thread.currentThread());
            throw throwable;
        }
    }

    @Override
    public Object runFunc(String name, Object... args) {
        BootTrace.mark("Main.runFunc enter name=" + name);
        try {
            Object result = super.runFunc(name, args);
            BootTrace.mark("Main.runFunc done name=" + name);
            return result;
        } catch (Throwable throwable) {
            BootTrace.crash(throwable, Thread.currentThread());
            throw throwable;
        }
    }

    @Override
    public void onCreate(Bundle savedInstanceState) {
        BootTrace.mark("Main.onCreate enter");
        try {
            super.onCreate(savedInstanceState);
        } catch (Throwable throwable) {
            BootTrace.crash(throwable, Thread.currentThread());
            throw throwable;
        }
        BootTrace.mark("Main.onCreate after super");
        if (savedInstanceState == null && getIntent().getData() != null) {
            runFunc("onNewIntent", getIntent());
        }
        if (getIntent().getBooleanExtra("isVersionChanged", false)
                && savedInstanceState == null) {
            runFunc("onVersionChanged",
                    getIntent().getStringExtra("newVersionName"),
                    getIntent().getStringExtra("oldVersionName"));
        }
        BootTrace.mark("Main.onCreate complete");
    }

    @Override
    protected void onStart() {
        BootTrace.mark("Main.onStart enter");
        super.onStart();
        BootTrace.mark("Main.onStart complete");
    }

    @Override
    protected void onResume() {
        BootTrace.mark("Main.onResume enter");
        super.onResume();
        BootTrace.mark("Main.onResume complete");
    }

    @Override
    protected void onNewIntent(Intent intent) {
        runFunc("onNewIntent", intent);
        super.onNewIntent(intent);
    }
}
