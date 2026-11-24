package com.mini.luaxplus;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.database.Cursor;
import android.net.Uri;
import android.util.Log;

/**
 * 最早的进程入口：在 Application.onCreate 之前建立启动轨迹、Java 崩溃捕获和原生信号捕获。
 * 不读取 Lua、不初始化界面，确保启动链前半段出问题时也留下文件。
 */
public class CrashBootstrapProvider extends ContentProvider {

    private static final String TAG = "CrashBootstrap";

    @Override
    public boolean onCreate() {
        try {
            BootTrace.init(getContext());
            BootTrace.mark("ContentProvider.onCreate");
            LogCore.init(getContext());
            RuntimeWatcher.setContext(getContext());
            RuntimeWatcher.installCrashHandler();
            NativeCrashGuard.install(LogCore.dir(), BootTrace.dir());
            CrashLedger.importLegacy(getContext());
            CrashLedger.importNative(getContext());
            ExitHistory.collect(getContext());
            BootTrace.mark("ContentProvider guards ready");
        } catch (Throwable throwable) {
            BootTrace.crash(throwable, Thread.currentThread());
            Log.e(TAG, "bootstrap failed", throwable);
        }
        return true;
    }

    @Override
    public Cursor query(Uri uri, String[] projection, String selection,
                        String[] selectionArgs, String sortOrder) {
        return null;
    }

    @Override
    public String getType(Uri uri) {
        return null;
    }

    @Override
    public Uri insert(Uri uri, ContentValues values) {
        return null;
    }

    @Override
    public int delete(Uri uri, String selection, String[] selectionArgs) {
        return 0;
    }

    @Override
    public int update(Uri uri, ContentValues values, String selection,
                      String[] selectionArgs) {
        return 0;
    }
}
