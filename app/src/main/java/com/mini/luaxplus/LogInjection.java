package com.mini.luaxplus;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.graphics.Color;
import android.text.method.ScrollingMovementMethod;
import android.util.TypedValue;
import android.view.ViewGroup;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.List;
import java.util.Locale;

/**
 * 成品崩溃报告入口：Java 异常写入 CrashLedger，启动页只消费未读记录。
 *
 * 报告在用户关闭弹窗后才标记已读，避免弹窗失败、用户杀进程或页面被系统回收时
 * 把崩溃快照提前清空。
 */
public final class LogInjection {

    private static final int MAX_SHOW = 3;
    private static final int MAX_TOTAL_CHARS = 16000;
    private static final SimpleDateFormat STAMP =
            new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US);

    private LogInjection() {
    }

    /** 在未捕获异常处理器里调用，只保存文本，不启动任何界面 */
    public static void recordCrash(Context context, Throwable error) {
        if (context == null || !LogPolicy.isEnabled(context)) {
            return;
        }
        String stack = error == null ? "未知崩溃" : android.util.Log.getStackTraceString(error);
        String file = LogCore.lastCrashExport();
        if (file == null || file.isEmpty()) {
            file = LogCore.lastCrashFile();
        }
        if (file == null || file.isEmpty()) {
            file = BootTrace.path();
        }
        String title = error == null
                ? "Java 未捕获异常"
                : "Java 未捕获异常：" + error.getClass().getSimpleName();
        CrashLedger.record(context, CrashLedger.SOURCE_JAVA, title, stack, file, null);
    }

    /** 启动页调用；只消费一次，避免每次启动都弹同一个旧崩溃 */
    public static void showPendingCrash(Activity activity) {
        showPendingCrash(activity, null);
    }

    /**
     * 展示上次崩溃后再继续启动。成品启动页会在展示完毕后立即关闭，
     * 因此必须等用户关闭报告后再执行后续页面跳转，否则日志会一闪而过。
     */
    public static void showPendingCrash(Activity activity, Runnable onDone) {
        if (activity == null || activity.isFinishing() || !LogPolicy.isEnabled(activity)) {
            run(onDone);
            return;
        }
        List<CrashLedger.Entry> entries;
        try {
            entries = CrashLedger.unread(activity, MAX_SHOW);
        } catch (Throwable error) {
            run(onDone);
            return;
        }
        if (entries == null || entries.isEmpty()) {
            run(onDone);
            return;
        }
        showDialog(activity, entries, onDone);
    }

    private static void run(Runnable action) {
        if (action != null) {
            action.run();
        }
    }

    private static void showDialog(final Activity activity,
                                   final List<CrashLedger.Entry> entries,
                                   final Runnable onDone) {
        StringBuilder message = new StringBuilder();
        StringBuilder fullMessage = new StringBuilder();
        for (CrashLedger.Entry entry : entries) {
            String block = "【" + entry.source + "】" + entry.title + "\n"
                    + "时间：" + STAMP.format(new Date(entry.time)) + "\n"
                    + "记录：" + (entry.path == null || entry.path.isEmpty()
                    ? "应用私有存储" : entry.path)
                    + "\n\n" + entry.detail + "\n";
            fullMessage.append(block).append('\n');
            if (message.length() + block.length() > MAX_TOTAL_CHARS) {
                int remain = MAX_TOTAL_CHARS - message.length();
                if (remain > 0) {
                    message.append(block, 0, Math.min(remain, block.length()));
                }
                message.append("\n…（界面已截断，复制内容仍完整）\n");
                continue;
            }
            message.append(block).append('\n');
        }
        final String copyContent = fullMessage.toString();

        TextView text = new TextView(activity);
        text.setText(message.toString());
        text.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12);
        text.setTextColor(Color.rgb(40, 40, 40));
        text.setTextIsSelectable(true);
        text.setPadding(dp(activity, 18), dp(activity, 12), dp(activity, 18), dp(activity, 12));
        text.setMovementMethod(new ScrollingMovementMethod());

        ScrollView scroll = new ScrollView(activity);
        scroll.addView(text, new ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        final boolean[] completed = {false};
        final Runnable complete = () -> {
            if (completed[0]) {
                return;
            }
            completed[0] = true;
            try {
                CrashLedger.markRead(activity, entries);
            } catch (Throwable ignored) {
                // 已读标记失败不影响继续启动，下一轮最多再展示一次
            }
            run(onDone);
        };
        AlertDialog dialog = new AlertDialog.Builder(activity)
                .setTitle("上次运行异常退出")
                .setView(scroll)
                .setPositiveButton("复制日志", (d, which) -> copy(activity, copyContent))
                .setNegativeButton("关闭", null)
                .create();
        dialog.setOnDismissListener(d -> complete.run());
        try {
            dialog.show();
        } catch (Throwable error) {
            // 弹窗失败时保留未读记录，下一次启动继续展示；不阻塞当前启动流程
            run(onDone);
        }
    }

    private static void copy(Activity activity, String text) {
        ClipboardManager manager = (ClipboardManager) activity.getSystemService(Context.CLIPBOARD_SERVICE);
        if (manager != null) {
            manager.setPrimaryClip(ClipData.newPlainText("Mini-LuaXPLUS 异常退出记录", text));
            Toast.makeText(activity, "异常退出记录已复制", Toast.LENGTH_SHORT).show();
        }
    }

    private static int dp(Context context, int value) {
        return Math.round(value * context.getResources().getDisplayMetrics().density);
    }
}
