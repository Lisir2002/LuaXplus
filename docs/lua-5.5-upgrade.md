# Mini-LuaXPLUS Lua 5.5 升级调研与实施设计

日期：2026-11-23  
范围：Lua 运行时、原生模块、LuaX-UI、打包器、插件/注入链路  
当前版本：1.0.0-rc41（versionCode 1000041）  
结论：**可以升级，建议采用“官方 Lua 5.5 语义 + 兼容层”方案，分五步落地，不做一次性大改。**

---

## 1. 版本事实

- Lua 5.3 的最后一个版本是 **5.3.6（2020-09-25）**，官方已经停止维护。
- Lua 5.4 的最后一个版本是 **5.4.9（2026-08-25）**，官方不再发布 5.4。
- Lua **5.5.0 发布于 2025-12-22**，**5.5.1 发布于 2026-08-03**，是当前最新稳定版。
- 官方明确说明：不同 Lua 版本之间没有 ABI 兼容性，嵌入方和 C 模块必须重新编译，预编译字节码也不能跨版本加载。

因此“官方只维护到 5.3”不成立；升级到 5.5.1 是合理选择。

---

## 2. 当前运行时审计

当前不是纯 Java 的 LuaJ，而是 **原生 Lua 5.3.3**：

- Java 桥接 JAR：`androlua/libs/AndroLua+5.0.18_AndroidX.jar`
- 真正的 Lua 内核：
  - `androlua/src/main/jniLibs/arm64-v8a/libluajava.so`
  - `androlua/src/main/jniLibs/armeabi-v7a/libluajava.so`
- `strings libluajava.so` 可看到 `Lua 5.3.3 Copyright (C) 1994-2016`。
- Java 包为 `com.luajava`，`LuaState` 共有 **118 个 native 方法**；现有 SO 正好导出 118 个对应符号。

上游完整源码已确认：

- 仓库：`https://github.com/nirenr/AndroLua_pro`
- 源码目录：`.research-androlua/app/src/main/jni`
- 包含 `lua/`、`luajava/` 以及 `bson`、`canvas`、`cjson`、`crypt`、`lfs`、`lluv`、`lsqlite3`、`luagl`、`luv`、`md5`、`regex`、`sensor`、`socket`、`tcc`、`xml`、`zip`、`zlib` 等模块源码。
- 上游 `lua/lua.h` 为 `LUA_VERSION_NUM 503`，即 Lua 5.3。

这意味着升级不需要从零写桥接，但需要重编 JNI 和全部 C 模块。

---

## 3. 已完成的实测

### 3.1 运行时原型

已用官方 Lua 5.5.1 源码与上游 JNI 源码做出可编译原型：

- arm64-v8a：`libluajava.so` 编译成功，版本字符串为 `Lua 5.5.1`。
- armeabi-v7a：同样编译成功。
- JNI 只改了两处：
  1. `luaL_register(L, "luajava", ljlib)` 改为 `luaL_newlib(L, ljlib)`；
  2. `lua_resume(L, L2, nArgs)` 改为 `lua_resume(L, L2, nArgs, &nres)`。
- 其余 `lua_newuserdata`、`lua_getuservalue`、`lua_setuservalue` 在 5.5 中仍有同名兼容宏，不需要改调用点。
- 原型导出 118 个 JNI 符号，与现有 JAR 的 native 方法一一对应。
- strip 后 arm64 `libluajava.so` 约 **360 KB**，与当前 364 KB 基本持平，APK 体积不会明显膨胀。

### 3.2 原生模块

用 Lua 5.5 头文件重编了源码可得的模块，arm64 与 armv7 均通过：

- 已成功：`bson`、`canvas`、`cjson`、`crypt`、`luv`、`md5`、`mime`、`regex`、`sensor`、`socket`、`tcc`、`xml`、`zip`、`zlib`，加上 `luajava` 共 15 个。
- `libgl` 只需处理一个桌面的 `glInitNames` 调用，属于历史 GL 绑定，不是 Lua 5.5 语义问题。
- `libthreads`、`libyaml` 没有上游源码；已核对它们的 Lua 符号，除 `luaL_openlibs`、`luaL_openlib`、`lua_newuserdata` 外没有别的旧接口。
- 已在 5.5 运行时中补出旧符号桥接：`lua_newuserdata`、`lua_getuservalue`、`lua_setuservalue`、`lua_objlen`、`luaL_openlib`、`luaL_register`、`luaL_openlibs`、`luaL_typerror`、`lua_pushunsigned`、`lua_tounsignedx`。
- 用这些桥接符号核对后，现有 `libgl`、`libthreads`、`libyaml`、`libtcc` 的 Lua 未定义符号都能被新运行时解析。

模块编译时的主要兼容点：

- `luaL_register` 在 5.5 已移除，需要兼容实现。
- `struct luaL_reg` 旧写法需要映射到 `luaL_Reg`。
- `luaL_checkint`、`luaL_checklong` 等旧转换需要打开 `LUA_COMPAT_APIINTCASTS` 或改用 `luaL_checkinteger`。
- `lua_pushunsigned`、`lua_tounsignedx` 需要兼容宏。
- `lua_objlen` 在 5.5 仍是 `lua_rawlen` 的兼容宏。
- `luv` 的 `c-api/compat-5.3.h` 在当前上游目录缺失；5.5 下实际不需要该头内容，可修条件或补空头。
- armv7 在 minSdk 21 下没有 `fseeko/ftello`（API 24 才引入），需要回退到 `fseek/ftell`；arm64 可直接用 64 位定位。
- `zip` 的 `mkstemp.c` 需要显式包含 `<unistd.h>`，这是旧源码在 NDK 27 下的编译问题。
- `tcc` 需要放宽旧式隐式函数声明；arm64 的 TCC 目标能力另行确认。

### 3.3 Lua 脚本语言兼容

用 Lua 5.5.1 对项目内 **88 个 Lua 源文件**做编译扫描：

- **81 个直接通过**。
- **7 个失败，全部是同一类问题：给 for 循环变量重新赋值**。5.5 把循环变量视为只读，赋值会在编译期报 `attempt to assign to const variable`。
- 需要改的 7 个文件：
  1. `androlua/src/main/resources/lua/import.lua`（`k`）
  2. `app/src/main/resources/lua/import.lua`（`k`）
  3. `app/src/main/assets/help.lua`（`t`、`c`）
  4. `app/src/main/assets/javaapi/fiximport.lua`（`k`）
  5. `app/src/main/assets/mainbody.lua`（`s`、`i`）
  6. `app/src/main/resources/lua/bin.lua`（`m`、`n`）
  7. `tools/lua-check/check_syntax.lua`（`line`）
- 修法统一：循环体内改用新的局部变量，不改变原业务含义。

旧标准库调用面：

- `module(...)`：4 个库文件（`base64.lua`、`console.lua`、`hex.lua`、`json.lua`）。
- `loadstring`：15 处，其中 `mainbody.lua` 有 4 参数用法；5.5 的 `load` 原生支持 4 参数，可直接映射。
- `unpack`：6 处实际调用，映射到 `table.unpack`。
- `table.getn`：1 处，映射到 `#`。
- `math.mod`：1 处，映射到 `math.fmod`。
- `string.gfind`：1 处，映射到 `string.gmatch`。
- `setfenv/getfenv`：0 处。
- `package.loaders`：0 处。
- 脚本中没有把 `global` 当变量名使用；5.5 默认开启 `LUA_COMPAT_GLOBAL` 也能兜底。

兼容层已在 5.5 本机验证：

- 实现 `module`、`package.seeall`、`loadstring`、`unpack`、`math.mod`、`table.getn`、`string.gfind`。
- `require "json"`、`require "base64"`、`require "hex"`、`require "console"` 均能加载。
- 现有 `tools/lua-smoke` 的页面加载、类搜索、打包预检、包名、图标、lint 回归在 5.5 下全部通过。
- `console.build` 在 5.5 下能生成 `.luac`，并能被 5.5 `loadfile` 回读。

### 3.4 组件库、打包与注入

LuaX-UI：

- 组件库没有 `module`、`loadstring`、`unpack` 依赖，5.5 语法扫描通过。
- 主要风险不是语法，而是数字打印格式和 `for` 循环变量；组件库自身不涉及后者。
- 需要重点回归令牌、字号、颜色、布局和长页滚动，避免 5.5 数字显示差异影响展示。

打包器：

- `console.build` 当前用 `loadfile` 读取源码，再 `string.dump(str,false)` 生成字节码。
- 5.5 宿主生成的 `.luac` 是 5.5 字节码；5.5 成品包能正常加载。
- 旧版 5.3 `.luac` 不能被 5.5 加载；`bin.lua` 当前会跳过源项目里的 `.luac`，不会把旧字节码带进新包。
- `bin.lua` 打包成品时按 `require/import` 收集模块，并从宿主 APK 复制同名 `.so`；`libluajava.so` 始终保留。只要新运行时和模块仍使用原文件名，打包链路不需要改文件名。
- 必须避免“新宿主 + 旧 `.luac`”混用；升级后第一次打包应清理旧产物并重新编译。

注入/插件链路：

- `import.lua` 的 DEX 加载、`loadDex`、`package.loadlib` 路径与 Lua 版本无关。
- 原生模块通过 `luaopen_*` 符号加载；5.5 运行时已保留旧模块需要的兼容符号，可先让旧预编译模块加载，再逐步替换。
- 真正的风险在 `libyaml`、`libthreads`、`libtcc` 这类无源码或旧工具链模块，不在 DEX 注入本身。

---

## 4. 推荐方案

### 4.1 运行时

采用 **官方 Lua 5.5.1 源码 + 现有 `com.luajava` JNI 桥**，不换 Java 桥、不换 LuaState API。

理由：

- 现有 JAR 的 118 个 native 方法与上游 JNI 源码完全对应，改造面最小。
- 现有脚本、`import`、`luajava`、LuaX-UI 都建立在 `com.luajava` 上，换桥会引发大面积回归。
- `lua-kmp` 等方案会改变 Java 调用方式和 minSdk，不适合当前项目。

### 4.2 兼容策略

- 原生层：保留 5.5 官方语义，同时导出旧模块需要的兼容符号。
- Lua 层：在 `import.lua` 顶部安装一层很小的兼容函数，覆盖 `module`、`loadstring`、`unpack`、`math.mod`、`table.getn`、`string.gfind`。
- 不全局改写 `tostring`，不关闭 5.5 的数字格式；接受官方行为，通过 UI 回归确认展示效果。
- 保留 `LUA_COMPAT_GLOBAL` 开启，避免旧脚本把 `global` 当普通名字时立刻失败。

### 4.3 原生模块策略

- 有源码的模块全部用 5.5 头文件重编，不再继续使用 5.3 预编译产物。
- 暂时无源码的 `libyaml`、`libthreads` 先通过兼容符号桥接继续加载，作为过渡；验证稳定后再决定补源码或移除。
- `libgl` 修复 `glInitNames` 后重编；`libtcc` 先保留 armv7 能力，arm64 需要确认 TCC 目标是否真的可用，不能只看“能编译”。
- `libthreads` 如果后续发现线程/协程行为异常，优先补源码重编，不长期依赖符号桥接。

---

## 5. 分步实施计划

### 第一步：原生构建底座

目标：让项目具备可重复的 5.5 原生构建，不替换生产 APK。

- 新增 `native/` 源码目录，放 Lua 5.5.1 核心、JNI、模块源码与兼容头。
- 在 `app` 或 `androlua` 模块接入 `externalNativeBuild`/CMake，配置 `armeabi-v7a`、`arm64-v8a`、minSdk 21。
- 加入 `-fvisibility=default`、strip、`LUA_COMPAT_GLOBAL`、32 位文件定位回退。
- 先生成 `libluajava.so`，对比 JNI 符号、版本字符串、体积。
- 验收：两套 ABI 均能产出，`nm` 118 个 JNI 符号齐全，`strings` 显示 Lua 5.5.1。

### 第二步：运行时替换与冒烟

目标：让宿主真正跑在 5.5 上。

- 用新 `libluajava.so` 替换 `androlua/src/main/jniLibs/` 两套旧库。
- 接入 JNI 两处修改和旧符号桥接。
- 在 `import.lua` 顶部加 Lua 兼容层。
- 跑 `tools/lua-check/run.sh`、`tools/lua-smoke/*`、编辑器保存审计。
- 验收：应用能启动，`require "import"` 正常，`json/base64/hex/console` 可加载，编辑器能打开并保存脚本。

### 第三步：脚本与组件库适配

目标：清掉 5.5 语言规则带来的确定性问题。

- 修 7 个 for 循环变量赋值文件。
- 补 `math.mod`、`table.getn`、`string.gfind` 等零星兼容。
- 全量扫描 `app/src/main/assets`、`app/src/main/resources`、`androlua/src/main/resources`。
- 回归 LuaX-UI 示例、长页、分页器、标签栏、头像组、原子组件。
- 验收：88 个文件 100% 通过 5.5 编译；组件示例无布局/字号/颜色回归。

### 第四步：打包与注入链路

目标：新宿主打出的成品包也是 5.5 且能启动。

- 用 5.5 宿主重新编译示例项目，确认 `.luac` 为 5.5 字节码。
- 检查 `bin.lua` 复制 `.so` 的清单：`libluajava`、`bson`、`canvas`、`cjson`、`crypt`、`luv`、`md5`、`mime`、`regex`、`sensor`、`socket`、`tcc`、`xml`、`zip`、`zlib`，以及按需的 `gl/threads/yaml`。
- 清理旧 `.luac`，避免 5.3/5.5 混用。
- 验收：成品包安装、启动、页面加载、插件 DEX 加载、原生模块 `require` 全部正常。

### 第五步：版本与交付

- 版本号按项目规则递增到 `1.0.0-rc41`。
- 更新 `CHANGELOG.md`、`README.md`、`docs/lua-5.5-upgrade.md`。
- 本地跑 analyze/test/lint 和 Lua 全量检查；正式发版按既有 GitHub Actions 规则执行。
- 交付前独立校验 APK 版本、签名 v1/v2/v3、原生库版本字符串、包大小。

---

## 6. 风险与待确认

1. **旧预编译模块的 ABI 风险**：`libyaml`、`libthreads` 没有源码，符号桥接只能保证“能解析”，不能保证所有内部行为完全正确。建议先过渡，后续补源码或移除。
2. **TCC 的 arm64 能力**：上游源码只有 32 位 ARM 后端；现有 arm64 `libtcc.so` 的来源和目标需要单独确认。若 arm64 不可用，应明确降级或移除，而不是带一个看似存在的库。
3. **旧 `.luac` 不兼容**：升级后不能加载 5.3 字节码。旧成品 APK 自带 5.3 运行时，仍可独立运行；新宿主打包必须重新生成。
4. **数字打印差异**：5.5 使用可回读精度，`0.1+0.2` 会显示 `0.30000000000000004`，5.3 显示 `0.3`。这是官方行为，需通过 UI 回归确认是否影响展示。
5. **minSdk 21**：建议保持，不为了 5.5 提高 minSdk；armv7 用 32 位文件定位回退即可。
6. **正式发版方式**：项目历史上是本地 Gradle 交付；如果这次要走正式 Release，需要按 GitHub Actions 规则另做 CI 配置，不能混用。

需要你确认的三件事：

- 是否接受“官方 5.5 语义 + 兼容层”，而不是为了旧脚本长期停留在 5.3 行为。
- `libyaml`、`libthreads` 是否允许先过渡保留，后续再补源码或移除。
- 升级后的第一个版本是否定为 `1.0.0-rc41`。

---

## 7. 验收清单

- [ ] arm64/armv7 `libluajava.so` 均显示 Lua 5.5.1。
- [ ] 118 个 JNI native 符号齐全。
- [ ] 88 个 Lua 文件全部通过 5.5 编译。
- [ ] `tools/lua-check/run.sh` 全绿。
- [ ] `tools/lua-smoke` 全部通过。
- [ ] 编辑器打开、保存、语法阻断、lint 修复正常。
- [ ] LuaX-UI 示例与长页无回归。
- [ ] 成品包安装启动，`.luac` 为 5.5 字节码。
- [ ] 所有随包原生模块可 `require`。
- [ ] APK 签名 v1/v2/v3 通过，版本号正确。

---

## 8. 第一步实施结果（2026-11-23）

原生构建底座已经落地，生产运行时尚未替换。

- 源码目录：`native/`
- 构建入口：`bash tools/native/build.sh`，或 `./gradlew :androlua:buildLua55Native`
- 构建产物：`build/native/<abi>/`，已被 `/build` 忽略，不进入仓库。
- 两套 ABI 均产出 **18 个库**：
  `libluajava`、`libbson`、`libcanvas`、`libcjson`、`libcrypt`、`libgl`、`libluv`、`libmd5`、`libmime`、`libregex`、`libsensor`、`libsocket`、`libtcc`、`libthreads`、`libxml`、`libyaml`、`libzip`、`libzlib`。
- 两套 `libluajava.so` 均显示 `Lua 5.5.1`，JNI 导出均为 **118 个**，包含旧版 `_LtoString` 别名。
- strip 后体积：arm64 `libluajava.so` 约 360KB，armv7 约 239KB；与原运行时 364KB 基本持平。
- `libyaml` 已补 `lyaml` + `libyaml` 源码，导出 `luaopen_yaml`。
- `libthreads` 已补 `llthreads2` 源码，按 `LLTHREAD_MODULE_NAME=threads` 编译，导出 `luaopen_threads`。
- `libgl` 已移除未注册的桌面 GL `glInitNames` 绑定并重编。
- 新旧 `luaopen_*` 入口对比：旧模块入口全部覆盖，新增的是 Lua 5.5 标准库入口，不是缺失。
- Gradle 任务 `:androlua:buildLua55Native` 已实际执行通过，构建耗时约 35 秒。

当时仍未做：

- 没有替换 `androlua/src/main/jniLibs` 下的生产 `.so`。
- 没有接入 APK 默认打包流程。
- 没有在真机验证 `libtcc` 的 arm64 代码生成能力，这一项仍按风险项单独验证。

---

## 9. 第二步实施结果（2026-11-23）

生产运行时已经替换为 Lua 5.5.1，脚本兼容层已接入，arm64 打包配置已收口。

### 9.1 运行时替换

- `androlua/src/main/jniLibs/arm64-v8a/libluajava.so` 与 `armeabi-v7a/libluajava.so` 均已换成 **Lua 5.5.1**，JNI 导出均为 **118 个**。
- `app/src/main/jniLibs/arm64-v8a/` 与 `armeabi-v7a/` 的 17 个模块库同步替换；`libluajava` 只保留在 `androlua`，避免重复打包。
- arm64 `libluajava.so` 的 SHA-256 为 `be648009c58de920e7729526c4d89bd42e25ad8e106d64ce41b1c797d0a4cfbb`，strip 后约 360KB。
- `abiFilters` 已改为只保留 `arm64-v8a`；`androlua` 的 `minSdkVersion` 对齐到 21。
- `tools/native/build.sh` 默认只构建 arm64，仍可通过参数手动构建 armv7。

### 9.2 脚本兼容

- 新增 `app/src/main/resources/lua/lua55_compat.lua` 与 `androlua/src/main/resources/lua/lua55_compat.lua`，内容一致。
- 两份 `import.lua` 顶部统一执行 `pcall(require, "lua55_compat")`，保证宿主、工程与插件脚本先装配兼容层。
- 兼容层覆盖 `loadstring`、`unpack`、`math.mod`、`math.pow`、`math.log10`、`table.getn`、`table.maxn`、`string.gfind`、`package.seeall`、`module`、`bit32`。
- 修复 7 个文件的 for 循环变量只读写法；`bin.lua` 的 `require` 与 `import` 两处循环、`mainbody.lua` 的 `navi` 均已处理。
- `mainbody.lua` 的 `onKeyShortcut` 与剪贴板 ActionMode 两段 Java 风格 `switch/case` 已改为等价 `if/elseif`，不再依赖历史例外。

### 9.3 验证结果

- `LUA_BIN=.research-lua55/lua-5.5.1/src/lua LUA_INIT=@app/src/main/resources/lua/lua55_compat.lua bash tools/lua-check/run.sh`
  - 语法通过：**74 个文件，跳过 0 个历史文件**。
  - LuaX-UI 页面、类搜索、类加载保护、详情、成员长按、详情搜索、详情关闭全部通过。
  - 打包预检、包名生成、图标着色、保存前审计全部通过。
- 额外的 5.5.1 全量 `loadfile` 扫描：**92 个 .lua 文件全部通过**（包含 `native/` 下的 Lua 源码）。
- `./gradlew :app:testDebugUnitTest --no-daemon` 执行成功；当前仓库没有单元测试源码，任务为 `NO-SOURCE`，但 Java 编译与 `luaCheck` 均已完成。
- 按当前约束，本地没有执行 `assembleRelease`，也没有构建 APK。

### 9.4 仍未验证

- 完整 APK 的打包、签名、安装与启动。
- 成品包的 `.luac` 是否为 5.5 字节码，以及插件/注入链路在 5.5 宿主中的实际行为。
- `libtcc` 的 arm64 代码生成、`libyaml` 与 `libthreads` 的真机行为。
- GitHub Actions 云端构建、签名 Secrets 与 Release 流程仍未配置。

### 9.5 当前构建入口

- 本地语法与冒烟：`LUA_BIN=/path/to/lua-5.5.1/src/lua LUA_INIT=@app/src/main/resources/lua/lua55_compat.lua bash tools/lua-check/run.sh`
- 本地单元测试：`./gradlew :app:testDebugUnitTest --no-daemon`
- 云端全量打包：待 GitHub Actions 工作流与签名 Secrets 就绪后执行。

