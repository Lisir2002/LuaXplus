package com.mini.luaxplus.editor;

import java.util.Locale;

import b.b.a.b.h;
import b.b.a.b.i;
import b.b.a.b.k;
import com.androlua.LuaEditor;

/** 编辑器语言识别与高亮切换入口。 */
public final class EditorLanguage {
    private EditorLanguage() {
    }

    public static String apply(LuaEditor editor, String path) {
        return applyById(editor, detect(path));
    }

    public static String applyById(LuaEditor editor, String language) {
        String id = language == null ? "lua" : language.trim().toLowerCase(Locale.ROOT);
        if ("lua".equals(id)) {
            k.h(i.E());
        } else {
            k.h(new LanguageHighlighter(id));
        }
        if (editor != null) {
            editor.respan();
        }
        return displayName(id);
    }

    public static String detect(String path) {
        String name = path == null ? "" : path.replace('\\', '/');
        int slash = name.lastIndexOf('/');
        if (slash >= 0) name = name.substring(slash + 1);
        String lower = name.toLowerCase(Locale.ROOT);
        if (lower.endsWith(".lua") || lower.endsWith(".aly")) return "lua";
        if (lower.endsWith(".java")) return "java";
        if (lower.endsWith(".kt") || lower.endsWith(".kts")) return "kotlin";
        if (lower.endsWith(".js") || lower.endsWith(".jsx") || lower.endsWith(".mjs") || lower.endsWith(".cjs")) return "javascript";
        if (lower.endsWith(".ts") || lower.endsWith(".tsx")) return "typescript";
        if (lower.endsWith(".py") || lower.endsWith(".pyw")) return "python";
        if (lower.endsWith(".c") || lower.endsWith(".h") || lower.endsWith(".m") || lower.endsWith(".mm")) return "c";
        if (lower.endsWith(".cpp") || lower.endsWith(".cc") || lower.endsWith(".cxx") || lower.endsWith(".hpp") || lower.endsWith(".hh") || lower.endsWith(".hxx")) return "cpp";
        if (lower.endsWith(".cs")) return "csharp";
        if (lower.endsWith(".go")) return "go";
        if (lower.endsWith(".rs")) return "rust";
        if (lower.endsWith(".swift")) return "swift";
        if (lower.endsWith(".php")) return "php";
        if (lower.endsWith(".rb")) return "ruby";
        if (lower.endsWith(".sh") || lower.endsWith(".bash") || lower.endsWith(".zsh")) return "shell";
        if (lower.endsWith(".html") || lower.endsWith(".htm") || lower.endsWith(".xml") || lower.endsWith(".svg") || lower.endsWith(".vue") || lower.endsWith(".svelte")) return "html";
        if (lower.endsWith(".css") || lower.endsWith(".scss") || lower.endsWith(".less")) return "css";
        if (lower.endsWith(".json") || lower.endsWith(".jsonc")) return "json";
        if (lower.endsWith(".yaml") || lower.endsWith(".yml")) return "yaml";
        if (lower.endsWith(".sql")) return "sql";
        if (lower.endsWith(".md") || lower.endsWith(".markdown")) return "markdown";
        if (lower.endsWith(".gradle")) return "groovy";
        if (lower.endsWith(".dart")) return "dart";
        if (lower.equals("dockerfile")) return "shell";
        if (lower.equals("makefile") || lower.equals(".gitignore")) return "plain";
        return "lua";
    }

    public static String displayName(String id) {
        switch (id == null ? "plain" : id) {
            case "lua": return "Lua";
            case "java": return "Java";
            case "kotlin": return "Kotlin";
            case "javascript": return "JavaScript";
            case "typescript": return "TypeScript";
            case "python": return "Python";
            case "c": return "C";
            case "cpp": return "C++";
            case "csharp": return "C#";
            case "go": return "Go";
            case "rust": return "Rust";
            case "swift": return "Swift";
            case "php": return "PHP";
            case "ruby": return "Ruby";
            case "shell": return "Shell";
            case "html": return "HTML / XML";
            case "css": return "CSS";
            case "json": return "JSON";
            case "yaml": return "YAML";
            case "sql": return "SQL";
            case "markdown": return "Markdown";
            case "groovy": return "Groovy";
            case "dart": return "Dart";
            default: return "纯文本";
        }
    }
}
