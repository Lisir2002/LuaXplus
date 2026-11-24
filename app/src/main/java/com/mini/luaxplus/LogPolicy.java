package com.mini.luaxplus;

import android.content.Context;

import java.io.InputStream;
import java.util.Properties;

/**
 * 成品日志策略：读取打包时写入的 logging.properties。
 *
 * 编辑器本体不启用成品崩溃报告，只有打包后的应用才读取这个开关；
 * 旧成品没有该文件时按启用处理，避免升级前的包失去崩溃提示。
 */
public final class LogPolicy {

    public static final String ASSET = "luaxplus/logging.properties";

    private LogPolicy() {
    }

    public static boolean isEnabled(Context context) {
        if (context == null || LogCore.OWNER_PACKAGE.equals(context.getPackageName())) {
            return false;
        }
        Properties properties = new Properties();
        try (InputStream input = context.getAssets().open(ASSET)) {
            properties.load(input);
        } catch (Throwable ignored) {
            return true;
        }
        String enabled = properties.getProperty("enabled", "true");
        return !"false".equalsIgnoreCase(enabled.trim());
    }
}
