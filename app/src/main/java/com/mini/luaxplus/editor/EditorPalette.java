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
        apply(editor, dark, dark ? 0xFF141A20 : 0xFFF7F1E6);
    }

    public static void apply(LuaEditor editor, boolean dark, int background) {
        if (editor == null) {
            return;
        }
        editor.setDark(dark);
        b scheme = editor.getColorScheme();
        if (scheme == null) {
            return;
        }

        int text;
        int baseword;
        int call;
        int comment;
        int keyword;
        int string;
        int number;
        int lineNumber;
        int punctuation;
        if (dark) {
            text = 0xFFF2F6FA;
            baseword = 0xFFA9D6FF;
            call = 0xFF9CDCFE;
            comment = 0xFF9AAAB6;
            keyword = 0xFFD6A8FF;
            string = 0xFFFFA8C8;
            number = 0xFFA8E6CF;
            lineNumber = 0xFF8494A0;
            punctuation = 0xFFC7D2DB;
        } else {
            text = 0xFF17222C;
            baseword = 0xFF0B4F7A;
            call = 0xFF1F5F8B;
            comment = 0xFF5E6F68;
            keyword = 0xFF6E2E92;
            string = 0xFFA3264B;
            number = 0xFF0F6B4F;
            lineNumber = 0xFF6C7B86;
            punctuation = 0xFF4F5F6C;
        }

        scheme.d(b.a.a, text);
        scheme.d(b.a.b, background);
        scheme.d(b.a.c, text);
        scheme.d(b.a.d, call);
        scheme.d(b.a.e, text);
        scheme.d(b.a.f, number);
        scheme.d(b.a.g, comment);
        // b.a.h 是选区底色，保持默认透明度。
        scheme.d(b.a.i, lineNumber);
        scheme.d(b.a.j, comment);
        scheme.d(b.a.k, keyword);
        scheme.d(b.a.l, baseword);
        scheme.d(b.a.m, call);
        scheme.d(b.a.n, string);
        scheme.d(b.a.o, call);
        scheme.d(b.a.p, call);
        scheme.d(b.a.q, call);
        scheme.d(b.a.r, punctuation);
    }
}
