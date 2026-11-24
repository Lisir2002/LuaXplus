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

## 7. 验收清单（当前状态）

- [x] arm64/armv7 `libluajava.so` 均显示 Lua 5.5.1。
- [x] 118 个 JNI native 符号齐全。
- [x] 74 个门禁文件与 92 个全量 Lua 文件全部通过 5.5 编译。
- [x] `tools/lua-check/run.sh` 全绿。
- [x] `tools/lua-smoke` 全部通过。
- [ ] 编辑器打开、保存、语法阻断、lint 修复正常（待真机）。
- [ ] LuaX-UI 示例与长页无回归（待真机）。
- [ ] 成品包安装启动，`.luac` 为 5.5 字节码（待云端构建与真机）。
- [ ] 所有随包原生模块可 `require`（待真机）。
- [ ] APK 签名 v1/v2/v3 通过，版本号正确（待云端构建）。

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
- 云端全量打包：`.github/workflows/release.yml` 已就绪，待仓库远端与签名 Secrets 配置后执行。



---

## 10. rc41 启动闪退定位与 rc42 修复（2026-11-23）

### 10.1 根因

`libluajava.so` 与 `AndroLua+5.0.18_AndroidX.jar` 不是同一条代码线。新原生代码按 `LuaJavaAPI(long, Object, ...)` 查找 Java 方法，但 JAR 里的桥接方法全部是 `long cptr + int 栈索引`，例如：

- 原生期望 `javaGc(Object)`，JAR 实际是 `javaGc(long, int)`。
- 原生期望 `callMethod(long, Object, String)`，JAR 实际是 `callMethod(long, int, String)`。

`LuaState.openLibs()` 进入 `luaopen_luajava` 时，`GetStaticMethodID` 找不到 `javaGc` 返回空，`checkError` 触发 Lua panic，随后 `abort()`。这类原生 abort 不会进入 Java `UncaughtExceptionHandler`，所以表现为“直接闪退、没有 LuaXPlus 快照”。

主机用同一份 JNI + Lua 5.5.1 复现，稳定输出：

```text
PANIC: unprotected error in call to Lua API (static Lcom/luajava/LuaJavaAPI;.javaGc(Ljava/lang/Object;)V)
```

### 10.2 修复

- 从与 `native/luajava/luajava.c` 同源的上游取出完整的 `com.luajava` Java 源码，编译进 `androlua` 模块。
- 从 `AndroLua+5.0.18_AndroidX.jar` 移除整套旧 `com.luajava` 字节码，避免新旧两套 `LuaState` 同时存在。
- 修正 Lua 5.5 的注册表伪索引：`LUA_REGISTRYINDEX` 由 `-LUAI_MAXSTACK-1000` 改为 `-(Integer.MAX_VALUE/2+1000)`，并重新编译引用该常量的类，修复 LuaObject 引用注册时的原生崩溃。
- 补齐旧版 `LuaState` 的 `LtoString`、`getJavaObject`、`removeJavaObject` 兼容入口，保证 JAR 内 `com.androlua` 层仍可调用。
- 主机验证：`newLuaState` → `openLibs` → 类绑定 → 方法调用 → `LuaObject` 字段读取全部通过，退出码 0。
- 新增 `MiniApplication`，在 Application 阶段初始化 `LogCore`、`RuntimeWatcher`。
- 新增 `libcrashguard.so`：接管 `SIGABRT`、`SIGSEGV`、`SIGBUS`、`SIGILL`、`SIGFPE`，先写 `native_crash_*.log`，再交还系统默认处理。

### 10.3 rc42 产物

- 版本：`1.0.0-rc42` / versionCode `1000042`。
- 仅 `arm64-v8a`，共 21 个 `.so`（18 个项目库 + Compose 2 个 + 崩溃守卫 1 个）。
- `libluajava.so` 仍为 Lua 5.5.1。
- v1/v2/v3 签名通过，证书 SHA-256 与 rc41 一致。

## 11. rc43：崩溃快照与四架构同包

### 11.1 崩溃无日志的两个断点

rc42 已经有 LogCore 和原生信号守卫，但真机仍然看不到新日志，审计后确认不是单点：

- `LuaApplication.onCreate()` 内部会调用 `CrashHandler.init(Context)`，而该方法会直接 `Thread.setDefaultUncaughtExceptionHandler(CrashHandler)`。`MiniApplication` 在 `attachBaseContext` 安装的处理器会被父类覆盖，Java 崩溃回到旧链路，只尝试写 `/sdcard/androlua/crash`，没有权限时就完全静默。
- 崩溃可能发生在 `Application.onCreate` 之前，尤其是 `LuaApplication` 初始化、静态类加载和 ContentProvider 创建阶段。只在 Welcome 或 onCreate 里初始化日志，覆盖不了这些阶段。

rc43 对应做了两件事：

- 新增 `CrashBootstrapProvider`，在 `Application.onCreate` 之前初始化 BootTrace、Java 异常捕获和原生信号守卫。Provider 只依赖 Android 基础 API，不读取 Lua、不初始化界面。
- 父类 `onCreate` 执行完成后调用 `RuntimeWatcher.refreshCrashHandler()`，强制重新接管默认异常处理器，并把父类 CrashHandler 作为上一级处理器保留，形成“BootTrace → LogCore → 旧 CrashHandler → 系统”的顺序。

### 11.2 启动轨迹落盘位置

BootTrace 会在所有可写目录同时追加 `boot_trace.log`，崩溃时额外生成 `crash_yyyyMMdd_HHmmss_SSS.log`：

- `Android/data/com.mini.luaxplus/files/boot_trace.log`，应用外部私有目录，卸载前一直保留。
- 应用内部 `files/boot_trace.log`，外部目录不可写时的兜底。
- `/storage/emulated/0/LuaXPlus/logs` 与 `/sdcard/androlua/crash`，仅在已授权存储时写入。

每次写入都执行 `flush` 与 `FileDescriptor.sync()`，避免进程被 `abort()` 终止时缓冲区丢失。原生信号日志由 `libcrashguard.so` 写入同样的目录，文件名为 `native_crash_<时间>_<pid>_<信号>.log`。

### 11.3 四架构同包

rc43 不再使用 ABI split，四个 ABI 的库全部进入同一个 APK：

- `arm64-v8a`：19 个项目库，`libluajava.so` 使用 Lua 5.5.1。
- `armeabi-v7a`：恢复旧版 32 位适配，补齐 `libcrashguard.so`，Lua 文件定位退回 32 位 `fseek/ftell`。
- `x86`：补齐 32 位模拟器库，同样退回 32 位文件定位。
- `x86_64`：补齐 64 位模拟器库，JNI 与 arm64 使用同一份 4.4.2 桥接实现。

打包结果：`native-code: 'arm64-v8a' 'armeabi-v7a' 'x86' 'x86_64'`，每个 ABI 21 个 `.so`，不生成 split APK。

### 11.4 rc43 产物

- 版本：`1.0.0-rc43` / versionCode `1000043`。
- 文件：`Mini-LuaXPLUS-1.0.0-rc43.apk`。
- 大小：15,190,423 字节。
- SHA-256：`bdd0d43647eb0a6b593ebf9f7e41655c04fc5d10cdf0c9873bc5edb78541a7dc`。
- 签名证书 SHA-256 与 rc42 一致，可直接覆盖安装。
- 主机侧已验证 `libcrashguard.so` 能接管 SIGABRT 并落盘完整信号日志。

## 12. rc49 → 1.0.1-rc1：日志初始化闪退修复

精确堆栈显示，rc49 的崩溃发生在 `MiniApplication.attachBaseContext` 内的 `LogCore.init`，并非 Lua 或原生守卫：`LogCore.write` 调用 `Environment.isExternalStorageManager()` 时，部分 ROM 在 Application.attach 早期尚未准备好包信息，抛出 `NullPointerException`。

处理方式：

- `LogCore.switchExternalIfPossible` 捕获该调用的全部异常，异常时直接跳过外部切换。
- `LogCore.init` 在 `getApplicationContext()` 返回空时回退到传入的基础上下文，保证内部目录可用。
- `LogCore.prepareExternal` 将目录探测的异常范围扩大到 `Throwable`，外部目录不可写时保持内部目录。
- `Permissions.allFiles` 同样捕获系统异常，权限查询不阻断启动。
- Android 11 及以上按版本引导一次所有文件访问，启动后授权成功即自动切换到 `/storage/emulated/0/LuaXPlus/logs`。

版本从 `1.0.0-rc49` 升到 `1.0.1-rc1`，versionCode `1000101`。四个 ABI 继续同包，不 split。

### rc1 实测结果与 rc2 诊断

rc1 在 vivo V2324A / Android 16 上已不再出现 LogCore 空指针，日志成功写入 `/storage/emulated/0/LuaXPlus/logs`，说明外部存储授权与目录切换已生效。

新的停止点在 `Main.onCreate` 的父类初始化阶段：`Activity created` 已写入，但 `Main.onCreate after super` 未出现，入口脚本的第一条日志也未出现。这说明崩溃发生在 Lua 运行环境初始化或入口脚本加载早期，而不是界面绘制阶段。

rc2 在 `Main` 的 `getLuaPath`、`initMain`、`doFile`、`runFunc` 前后增加轨迹，并捕获 Throwable 写快照；原生守卫改为先写最小崩溃文件，再尝试 `_Unwind_Backtrace`，避免回溯本身异常导致无文件可查。

### rc2 实测结果与 rc3 根因

rc2 日志仍停在 `Activity created com.androlua.Main`，且没有出现 `Main.getLuaPath enter`。继续反汇编父类 `LuaActivity.onCreate` 后发现一段旧代码：

```java
LuaApplication app = (LuaApplication) getApplication();
if (app.getClass() != LuaApplication.class) {
    while (true) {
        if (app.getClass() == LuaApplication.class) {
            break;
        }
    }
}
```

它要求应用类精确等于 `LuaApplication`。本项目为了启动日志与崩溃守卫，使用 `MiniApplication extends LuaApplication`，精确类判断永远不成立，主线程因此进入忙等，表现为停在 `Activity created` 后无任何日志、随后被系统或用户终止。

rc3 通过字节码补丁移除这段死循环。补丁只删除 `onCreate` 中的类判断与忙等，不改变字段、方法签名和其他逻辑。构建后的 DEX 已核对：`getApplication` 之后直接进入 `getLocalDir`，不存在类判断分支。

### rc3 实测结果与 rc4

rc3 已突破首页入口，应用不再卡在 `Activity created`。随后在打包工程“啤酒”时出现新的原生 `SIGSEGV`，并且 Lua 快照记录了“打包配置读取失败”。

该 Lua 错误来自 `bin.lua` 中 `pcall(loadfile(...))` 的判断写反：`pcall` 成功时返回 true，原逻辑却把成功当成失败，弹出错误框并继续打包。rc4 改为成功时执行配置块，失败时提示并直接返回。

原生崩溃文件已能产出，但只有裸地址。rc4 在信号处理里加入 `dladdr`，崩溃文件会写明 `libxxx.so+偏移 符号`，下一次可直接定位到具体原生函数。

### rc4 原生栈定位与 rc5 修复

rc4 崩溃文件已经符号化，调用栈落在：

- `libluajava.so+0x1d1e8 lua_dump`
- `Java_com_luajava_LuaState__1dump`
- `libluajava.so+0x1f8bc luaL_addlstring`
- `libc.so` 内存操作

根因是 Lua 5.5 修改了 `luaL_Buffer` 的栈约定：`luaL_buffinit` 会压入一个 lightuserdata 占位值。旧桥接先 `luaL_buffinit`，再调用 `lua_dump(L, writer, &b, 0)`，此时栈顶已经不是待 dump 的函数，`lua_dump` 取到占位值，writer 又把占位值当成缓冲盒，最终在 `luaL_addlstring` 内越界崩溃。

rc5 把 dump 的输出改为独立 C 动态缓冲区，writer 直接向 `malloc/realloc` 的缓冲区追加，不再创建 `luaL_Buffer`，也不再向 Lua 栈压占位值。`lua_dump` 始终 dump 栈顶函数，序列化完成后再复制到 Java `byte[]`。

### rc5 实测结果与 rc6

rc5 没有再产生原生 SIGSEGV，说明 `lua_dump` 的独立缓冲区修复有效。打包继续进入修改清单阶段，出现两个 Lua 层错误：

1. `bin.lua:394 attempt to call a nil value (global 'tointeger')`。旧运行环境提供全局 `tointeger`，Lua 5.5 运行时没有该全局；rc6 在打包函数作用域内提供本地实现，用 `tonumber` 与 `math.floor` 转换。
2. `bin.lua:33 attempt to index a nil value (upvalue 'error_dlg')`。rc4 移除配置误报后，成功路径不再提前创建错误框，失败回调仍直接使用它；rc6 改为需要时按需创建。

这两处都不涉及原生层。

### rc6 成品安装冲突与 rc7

rc6 已成功产出 `啤酒_1.0.apk`（包名 `com.mini.pijiu`，版本名 1.0），但安装时提示“软件包与现有软件包存在冲突”。

检查成品清单发现版本号被写成 1，而打包器自身版本号是 1000106。`bin.lua` 在写完整清单后，用 `string.gsub` 对二进制 XML 做四字节替换：

```lua
s = string.gsub(s, touint32(code), touint32(tointeger(appcode) or 1), 1)
```

`touint32(1)` 会匹配二进制 XML 中大量值为 1 的字段，既可能把版本号降级，也可能误改 `uses-feature` 的 `android:required` 等属性。安装器因此把成品判成降级包或结构异常包。

rc7 删除这两处二进制替换。成品版本号继承打包器版本号，版本名仍通过字符串表替换；清单不再被字节级改写。若旧成品是同包名但不同签名，需要先卸载旧版，这是 Android 的签名约束，不是清单问题。

### rc8 成品与主程序安装冲突

rc7 重新打包后，成品版本号已恢复为 `1000107`，清单也能被 `aapt` 正常解析，但安装仍提示“软件包与现有软件包存在冲突”，且设备上没有同包名旧版。

解码成品清单后确认，成品包名是 `com.mini.pijiu`，与主程序 `com.mini.luaxplus` 不同；真正的冲突来自 ContentProvider 标识：

```xml
<provider
    android:name="com.mini.luaxplus.CrashBootstrapProvider"
    android:authorities="com.mini.luaxplus.crashbootstrap" />
```

Android 要求已安装应用的 ContentProvider authority 全局唯一。成品沿用了主程序已经占用的 `com.mini.luaxplus.crashbootstrap`，安装器因此拒绝安装，表现就是“与现有软件包冲突”。

rc8 在 `bin.lua` 的清单字符串替换表中补上：

```lua
[activity.getPackageName()..".crashbootstrap"] = packagename..".crashbootstrap"
```

成品重新打包后，authority 变为 `com.mini.pijiu.crashbootstrap`，不再与主程序冲突。

### rc9 资源包名仍与主程序重名

rc8 修掉 `crashbootstrap` 的 Provider 标识后，成品仍被 vivo 拒绝。继续解码成品发现，`resources.arsc` 的资源包名还是 `com.mini.luaxplus`：

```
Package 0 id=0x7f name=com.mini.luaxplus
```

也就是说，清单里的包名已经变成 `com.mini.pijiu`，但资源表仍把自己标成主程序。部分安装器会读资源表包名做同名判断，于是仍然报“软件包与现有软件包存在冲突”。

rc9 新增 `ArscPackage`，在打包复制 `resources.arsc` 时定位 `RES_TABLE_PACKAGE_TYPE` 块，把 128 字符的包名改成成品包名。资源 ID 的 `0x7f` 命名空间不变，只改资源表身份。成品现在是清单包名、Provider 标识、动态权限、资源包名四层一致。

### rc10 资源表不能压缩

rc9 已把 `resources.arsc` 的资源包名改成成品包名，但修复测试包在 vivo 上提示“安装应用与当前系统有兼容性问题”。对比原包和修复包的 ZIP 结构发现：

- 原包 `resources.arsc` 是 `Stored`，不压缩
- 修复包重新打包时把 `resources.arsc` 变成了 `Defl:N`

部分安装器要求资源表保持未压缩，压缩后会判定为不兼容包。rc10 的 `ArscPackage.writeStored` 在改写资源包名的同时，按 `STORED` 方式写入 `resources.arsc`，并设置正确的 size 和 CRC。

### rc11 布局加载的 _ENV 空值

rc10 安装后打开 Java API 页面，`javaapi/main.lua` 的 `import "classitem"` 触发 `.aly` 布局加载，报：

```
[string "javaapi/classitem.aly"]:2: attempt to index a nil value (upvalue '_ENV')
```

根因在 `lua55_compat.lua` 的 `loadstring` 兼容实现：它把第四个参数 `env` 无条件传给 `load`。旧 `loadstring` 调用通常只传 3 个参数，此时 `env` 是 `nil`，Lua 5.5 的 `load` 会给代码块一个空的 `_ENV`，布局里的 `LinearLayout` 等全局类无法解析。

修复为：只有 `env` 非 nil 时才传第四个参数；否则调用 `load` 的三参数形式，使用全局环境。显式传 env 的工程 `init.lua` 加载路径保持不变。
