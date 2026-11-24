# Lua 检查门禁

`run.sh` 是构建和 CI 共用的入口，包含四项检查：

1. **原生库版本检查**：`libluajava.so` 必须包含 `Lua 5.5.1`，且 JAR 内不能残留旧 `com.luajava` 字节码。
2. **语法检查**：对 `app/src/main/assets` 和 `app/src/main/resources` 下的所有 `.lua` 文件执行 `loadfile`，只编译不执行。
3. **JavaAPI 契约测试**：用严格 mock 运行 `javaapi/main.lua`，覆盖页面加载、类搜索、类加载失败、详情构建、成员搜索、长按复制、弹窗关闭和重开。
4. **打包预检回归**：用临时工程验证 `packcheck` 能发现缺失入口、Lua 语法错误、布局语法错误，并正确跳过隐藏文件与子目录合法文件。

## 为什么需要严格 mock

Lua 的 `obj:getName()` 是合法语法，但 LuaJava 会把 `obj` 作为第一个参数传给零参数的 Java 方法，运行期才会报：

```
Invalid method call. Invalid Parameters.
```

普通 mock 如果不检查参数数量，也会把这个错误放过。`tools/lua-smoke/run.lua` 里的 `javaZero` 会统计参数数量，多一个 `self` 就立即失败，因此这类回归会在构建阶段被拦住。

## 本地运行

```bash
bash tools/lua-check/run.sh
```

只检查原生库版本：

```bash
bash tools/lua-check/check_native.sh
```

Gradle 任务：

```bash
./gradlew :app:luaCheck
```

`luaCheck` 已挂到 `preBuild`，执行 `assembleRelease` 时会自动运行；`check` 任务也会依赖它。

## 历史例外

`tools/lua-check/known-legacy.txt` 记录暂不纳入语法检查的文件。目前只有 `mainbody.lua`：它是早期编辑器壳，当前入口不使用，文件内保留了 C 风格的 `switch/case` 伪代码。修复或删除该文件后，应同步删除例外行，避免例外长期累积。

## 应用内打包预检

`app/src/main/resources/lua/packcheck.lua` 会在应用内打包开始前只读扫描工程：

- `main.lua` 是否存在；
- 所有 `.lua` 能否通过 `loadfile` 语法编译；
- 所有 `.aly` 能否按 `local layout=<内容>` 的方式解析。

发现问题时 `bin.lua` 直接返回“打包前检查失败”清单，不进入压缩、签名和 APK 分发。它只做语法预检，不能发现 JavaAPI 这类运行期方法契约错误。

## 测试数据

为了不依赖真实的 6385 个类索引，契约测试用两个模块数据模拟：

- `android.view.View`（重复项去重）
- `androidx.appcompat.widget.AppCompatTextView`
- `androidx.core.internal.package-info`（应被过滤）

测试还会模拟一个零参数 Java 类，覆盖构造方法、事件、getter、setter、字段和普通方法。
