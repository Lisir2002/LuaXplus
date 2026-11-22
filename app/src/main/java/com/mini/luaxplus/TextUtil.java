package com.mini.luaxplus;

/**
 * 供脚本按字符定位文本的小工具。
 * Lua 的 # 与 string.find 按字节计数，光标位置按字符计数，中文多时会错位，
 * 统一走这里的 Java 实现可以避免此类问题。
 */
public final class TextUtil {

    private TextUtil() {
    }

    public static int indexOf(String text, String target, int from) {
        if (text == null || target == null || target.isEmpty()) {
            return -1;
        }
        return text.indexOf(target, Math.max(0, from));
    }

    public static int lastIndexOf(String text, String target, int from) {
        if (text == null || target == null || target.isEmpty()) {
            return -1;
        }
        return text.lastIndexOf(target, from);
    }

    public static String substring(String text, int start, int end) {
        if (text == null) {
            return "";
        }
        int length = text.length();
        int from = Math.max(0, Math.min(start, length));
        int to = Math.max(from, Math.min(end, length));
        return text.substring(from, to);
    }

    public static int length(String text) {
        return text == null ? 0 : text.length();
    }
}
