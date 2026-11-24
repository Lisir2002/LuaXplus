package com.mini.luaxplus;

import android.app.ActivityManager;
import android.app.ApplicationExitInfo;
import android.content.Context;
import android.os.Build;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.List;
import java.util.Locale;

/**
 * 系统退出历史回收：ANR、native 崩溃、低内存被杀、强制停止等不会触发
 * Java UncaughtExceptionHandler 的退出，只能在下一次启动时从系统查询。
 */
public final class ExitHistory {

    private static final int MAX_RECORDS = 20;
    private static final int MAX_TRACE_CHARS = 32 * 1024;
    private static final SimpleDateFormat STAMP =
            new SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US);
    private static boolean collected;

    private ExitHistory() {
    }

    public static void collect(Context context) {
        if (context == null || Build.VERSION.SDK_INT < 30) {
            return;
        }
        synchronized (ExitHistory.class) {
            if (collected) {
                return;
            }
            collected = true;
        }
        try {
            ActivityManager manager = (ActivityManager) context.getSystemService(
                    Context.ACTIVITY_SERVICE);
            if (manager == null) {
                return;
            }
            List<ApplicationExitInfo> reasons = manager.getHistoricalProcessExitReasons(
                    context.getPackageName(), 0, MAX_RECORDS);
            if (reasons == null) {
                return;
            }
            for (ApplicationExitInfo info : reasons) {
                if (info == null) {
                    continue;
                }
                int reason = info.getReason();
                if (!worthReporting(reason)) {
                    continue;
                }
                String name = reasonName(reason);
                long time = info.getTimestamp();
                String description = info.getDescription();
                String trace = readTrace(info);
                StringBuilder detail = new StringBuilder();
                detail.append("时间: ").append(STAMP.format(new Date(time))).append('\n');
                detail.append("系统退出原因: ").append(name)
                        .append(" (").append(reason).append(")\n");
                detail.append("进程重要性: ").append(info.getImportance()).append('\n');
                if (description != null && !description.trim().isEmpty()) {
                    detail.append("系统描述: ").append(description.trim()).append('\n');
                }
                if (trace != null && !trace.isEmpty()) {
                    detail.append("系统轨迹:\n").append(trace);
                }
                CrashLedger.record(context, CrashLedger.SOURCE_EXIT,
                        "系统异常退出：" + name, detail.toString(), null,
                        "exit_" + time + "_" + reason);
            }
        } catch (Throwable throwable) {
            android.util.Log.w("ExitHistory", "读取系统退出历史失败", throwable);
        }
    }

    private static boolean worthReporting(int reason) {
        switch (reason) {
            case ApplicationExitInfo.REASON_SIGNALED:
            case ApplicationExitInfo.REASON_LOW_MEMORY:
            case ApplicationExitInfo.REASON_CRASH:
            case ApplicationExitInfo.REASON_CRASH_NATIVE:
            case ApplicationExitInfo.REASON_ANR:
            case ApplicationExitInfo.REASON_INITIALIZATION_FAILURE:
            case ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE:
            case ApplicationExitInfo.REASON_USER_STOPPED:
            case ApplicationExitInfo.REASON_FREEZER:
                return true;
            default:
                // REASON_UNKNOWN / REASON_EXIT_SELF / REASON_OTHER / 升级、卸载等正常状态
                return false;
        }
    }

    private static String reasonName(int reason) {
        switch (reason) {
            case ApplicationExitInfo.REASON_SIGNALED:
                return "被信号终止";
            case ApplicationExitInfo.REASON_LOW_MEMORY:
                return "低内存被杀";
            case ApplicationExitInfo.REASON_CRASH:
                return "Java 崩溃";
            case ApplicationExitInfo.REASON_CRASH_NATIVE:
                return "原生崩溃";
            case ApplicationExitInfo.REASON_ANR:
                return "ANR";
            case ApplicationExitInfo.REASON_INITIALIZATION_FAILURE:
                return "初始化失败";
            case ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE:
                return "资源使用过量";
            case ApplicationExitInfo.REASON_USER_STOPPED:
                return "用户强制停止";
            case ApplicationExitInfo.REASON_FREEZER:
                return "系统冻结";
            default:
                return "未知退出(" + reason + ")";
        }
    }

    private static String readTrace(ApplicationExitInfo info) {
        InputStream input = null;
        try {
            input = info.getTraceInputStream();
            if (input == null) {
                return "";
            }
            ByteArrayOutputStream output = new ByteArrayOutputStream();
            byte[] buffer = new byte[8192];
            int count;
            int total = 0;
            while ((count = input.read(buffer)) != -1 && total < MAX_TRACE_CHARS) {
                output.write(buffer, 0, count);
                total += count;
            }
            return output.toString("UTF-8");
        } catch (Throwable ignored) {
            return "";
        } finally {
            if (input != null) {
                try {
                    input.close();
                } catch (Throwable ignored) {
                }
            }
        }
    }
}
