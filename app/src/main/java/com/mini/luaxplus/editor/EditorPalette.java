package com.mini.luaxplus.editor;

import b.b.a.b.b;
import com.androlua.LuaEditor;

/**
 * 编辑器语法高亮配色。
 *
 * <p>LuaEditor 默认配色里部分标识符颜色非常深，放在深色背景上几乎不可见。
 * 这里直接覆盖配色方案的每个语义槽位，保证关键字、函数名、字段名、字符串、
 * 注释和普通标识符都有足够对比度。</p>
 */
public final class EditorPalette {
    private EditorPalette() {
    }

    public static void apply(LuaEditor editor, boolean dark) {
        if (editor == null) {
            return;
        }
        editor.setDark(dark);
        b scheme = editor.getColorScheme();
        if (scheme == null) {
            return;
        }

        int text;
        int identifier;
        int call;
        int comment;
        int keyword;
        int string;
        int number;
        int lineNumber;
        int punctuation;
        if (dark) {
            text = 0xFFE8EEF4;
            identifier = 0xFFE8EEF4;
            call = 0xFF9CDCFE;
            comment = 0xFF8A9AA6;
            keyword = 0xFFC792EA;
            string = 0xFFF48FB1;
            number = 0xFF8FD3F4;
            lineNumber = 0xFF6F7F8A;
            punctuation = 0xFFB8C4CE;
        } else {
            text = 0xFF1C2B3A;
            identifier = 0xFF1C2B3A;
            call = 0xFF1F5F8B;
            comment = 0xFF6F7F72;
            keyword = 0xFF7A3E9D;
            string = 0xFFB03A5B;
            number = 0xFF1F5F8B;
            lineNumber = 0xFF7D8B96;
            punctuation = 0xFF5F6F7C;
        }

        scheme.d(b.a.a, text);
        scheme.d(b.a.b, identifier);
        scheme.d(b.a.c, identifier);
        scheme.d(b.a.d, call);
        scheme.d(b.a.e, identifier);
        scheme.d(b.a.f, number);
        scheme.d(b.a.g, comment);
        // b.a.h 是选区底色，保持默认透明度。
        scheme.d(b.a.i, lineNumber);
        scheme.d(b.a.j, comment);
        scheme.d(b.a.k, keyword);
        scheme.d(b.a.l, identifier);
        scheme.d(b.a.m, call);
        scheme.d(b.a.n, string);
        scheme.d(b.a.o, call);
        scheme.d(b.a.p, call);
        scheme.d(b.a.q, call);
        scheme.d(b.a.r, punctuation);
    }
}
