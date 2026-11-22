# Lua 5.5 原生源码

本目录是 Mini-LuaXPLUS 的 Lua 5.5.1 原生构建源码，和 APK 里的旧 `jniLibs` 预编译库分离，先用于可重复构建和验证。

## 来源

- Lua 核心：官方 `lua-5.5.1.tar.gz` 的 `src/`，移除了独立解释器 `lua.c` 和编译器 `luac.c`。
- JNI 桥：`nirenr/AndroLua_pro` 的 `app/src/main/jni/luajava`。
- 原生模块：同一上游仓库的 `bson`、`canvas`、`cjson`、`crypt`、`luv`、`md5`、`regex`、`sensor`、`socket`、`tcc`、`xml`、`zip`、`zlib`、`luagl`。
- YAML：`gvvaughan/lyaml` 的 `ext/yaml` 绑定 + `yaml/libyaml` 的 C 实现。
- 线程：`moteus/lua-llthreads2`，以 `LLTHREAD_MODULE_NAME=threads` 编译，保持原模块名和 `luaopen_threads` 导出。

## 构建

```bash
bash tools/native/build.sh "arm64-v8a armeabi-v7a"
```

产物在 `build/native/<abi>/`，两套 ABI 各包含 18 个库：`libluajava` 和全部模块。

## 兼容点

- `compat/lua55_compat.h`：补 `luaL_openlib`、`luaL_register`、`luaL_reg`、旧整数转换和 unsigned 接口。
- `compat/lua55_abi_bridge.c`：在 `libluajava.so` 中导出旧模块仍可能引用的 5.3 符号。
- `compat/lua55_android.h`：armv7 在 minSdk 21 下退回 32 位文件定位。
- `modules/luagl/luagl.c` 移除了未注册的桌面 GL `glInitNames` 绑定。
- `modules/luv/luv/luv.h` 只在 Lua < 5.3 时引入旧兼容头。

## 版本

- Lua 5.5.1
- AndroLua_pro `abe5c25`
- libyaml `fc96aa6`
- lyaml `e9ca78d`
- llthreads2 `edd6035`

## Gradle 入口

```bash
./gradlew :androlua:buildLua55Native
```

## 当前状态

本目录只产出可验证的原生库，还没有替换 `androlua/src/main/jniLibs`，也没有接入 APK 打包。
