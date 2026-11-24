package com.baidu.mobstat;

import android.content.Context;

/** 统计 SDK 的本地空实现，保留旧代码调用点，避免第三方库接管崩溃处理。 */
public final class StatService {

    public static final int EXCEPTION_LOG = 1;
    public static final int JAVA_EXCEPTION_LOG = 2;

    private StatService() {
    }

    public static void start(Context context) {
    }

    public static void setAppKey(String appKey) {
    }

    public static void setAppChannel(Context context, String channel, boolean auto) {
    }

    public static void setOn(Context context, int flags) {
    }

    public static void onPageStart(Context context, String page) {
    }

    public static void onPageEnd(Context context, String page) {
    }
}
