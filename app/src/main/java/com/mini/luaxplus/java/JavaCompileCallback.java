package com.mini.luaxplus.java;

/** 供 Lua 代理使用的异步编译回调。 */
public interface JavaCompileCallback {
    void onResult(JavaProjectCompiler.CompileResult result);
}
