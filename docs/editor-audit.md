# 保存前 Lua 智能审计

编辑器在保存前会做一次静态检查，重点拦住“代码能写出来、运行才报 nil”的引用问题。检查逻辑独立在 `app/src/main/assets/lua/luaxplus/lint.lua`，不绑定编辑器界面，也不绑定某一个组件库。

## 触发位置

- 保存按钮：先检查，再写入文件。
- 另存为：先检查，再写入目标文件。
- 退出确认里的“保存并退出”：先检查，再保存并退出。
- 菜单“代码检查”：随时查看完整结果，包括未使用变量、作用域遮蔽等提示。

保存时只弹出会影响运行的错误和警告；只有未使用变量这类提示时直接保存，避免每次保存都被打断。菜单“代码检查”可以看到全部结果。

## 检查能力

第一级：当前文件引用

- 识别 `ui`、`theme`、`icons`、`pkgname` 等已知库被使用但未 `require`。
- 识别 `ui.show{}`、`icons.view(...)` 这种成员调用的基名。
- 跳过注释、普通字符串、长字符串、表键和成员属性名，避免把 `t.ui`、`{ ui = 1 }` 当成引用。
- 已知库缺失时生成 `local ui = require "luaxplus.ui"` 补丁。

第二级：工程级定义索引

- 扫描当前项目内全部 `.lua` 文件。
- 收集顶层 `function name(...)`、`name = ...` 定义。
- 当前文件引用其他文件顶层定义时不报“未定义”。
- 仍会标注“声明前使用”等可疑情况，但不自动插入重复声明。

第三级：细提示

- 未使用的局部变量。
- 未定义全局变量，附带相近拼写建议。
- 局部变量遮蔽外层变量或全局名字。
- 这些问题只提示，不自动修改代码。

## 一键补全

弹窗上的“一键补全”只处理高置信的已知库引用：

- 补丁插入在第一个代码行之前，保留文件头注释。
- 多个缺失库合并插入，按名称排序，避免重复。
- 已经正确 `require` 的库不会重复插入。
- 变量声明在引用之后时，不自动补全，只提示“声明前使用”。
- 未知全局变量不自动补全，避免猜错业务代码。

弹窗同时保留“仍然保存”和“取消”。静态分析无法覆盖所有 Lua 动态写法，因此审计不会强制阻断保存。

## 自研库接入

后续新增自研库不需要修改审计核心，任选一种方式。

### 方式一：项目内清单

在项目根目录或 `lua/` 下放 `lint-libs.lua`：

```lua
return {
  { name = "net", module = "acme.net", description = "网络请求" },
  { name = "store", module = "acme.store", description = "本地存储" },
}
```

`name` 是代码里使用的全局名，`module` 是 `require` 的完整模块路径。审计会生成：

```lua
local net = require "acme.net"
```

### 方式二：目录自动发现

把库文件放在项目 `lua/` 或 `lib/` 下：

```text
lua/acme/net.lua      -> 别名 net，模块 acme.net
lua/acme/store.lua    -> 别名 store，模块 acme.store
lua/acme/init.lua     -> 别名 acme，模块 acme
```

别名必须唯一。两个不同文件都叫 `net.lua` 时，审计不会猜路径，也不会自动补全。

### 方式三：运行期注册

库自身或启动脚本可以调用：

```lua
local lint = require "luaxplus.lint"
lint.registerLibrary({
  name = "net",
  module = "acme.net",
  description = "网络请求",
})
```

这种方式适合库自己有初始化入口、又希望被审计识别的场景。

## 内置库

当前内置清单：

```text
ui       -> luaxplus.ui
theme    -> luaxplus.theme
icons    -> luaxplus.icons
pkgname  -> luaxplus.pkgname
```

新增官方库时优先改 `DEFAULT_LIBRARIES` 或放项目清单；不要把库名硬编码到编辑器保存流程里。

## 已知边界

- 审计是静态分析，不执行代码。
- `import "android.widget.*"` 可能带进任意类名，因此带通配符 import 的文件不把大写开头名字报成缺失引用。
- `loadstring`、`load`、`_G[...]` 等动态写法会让全局名不可静态确定，只给低置信提示。
- 函数内部引用后面才声明的局部变量时，静态作用域和运行期闭包可能不同，审计降级为提示，不阻断保存。
- 无法承诺零误报；设计上优先保证“不误删代码、不强制阻断保存”。

## 验证

```bash
bash tools/lua-check/run.sh
```

其中 `tools/lua-smoke/lint_test.lua` 覆盖：

- 缺引用识别与一键补全。
- 多库合并补全与文件头保留。
- 工程级跨文件定义。
- 自研库清单和目录自动发现。
- 注释、字符串、表键、import、引擎全局不误报。
- 未使用变量、拼写建议、作用域遮蔽和声明前使用。
