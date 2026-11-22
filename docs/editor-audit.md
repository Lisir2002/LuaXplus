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

## 分级修复

弹窗上的“查看修复方案”会列出当前问题能生成的代码动作，按置信度分级：

- **安全**：语义唯一，可直接勾选应用，例如补 `local ui = require "luaxplus.ui"`。
- **需确认**：能生成可运行骨架，但业务含义需要用户确认，例如 `local page = ui.page{}`、空函数占位、拼写重命名。
- **手动**：无法可靠推断的问题只解释原因，不生成动作，例如未知表成员 `foo.bar()`、动态 `_G[name]`。

### 语法错误阻断保存

保存前先用 Lua 自带的 `load` 编译一次源码。出现缺右括号、缺 `end`、字符串未闭合等语法错误时：

- 只显示一条 LX1012 语法错误，不再用“未使用变量”等提示淹没真正原因；
- 标记为阻断项，弹窗标题为“无法保存：语法错误”，只提供“返回修改”；
- 不生成一键修复，避免对不完整源码做猜测性改写。

例如：

```lua
local note = ui.textArea{
  label = "备注",
  lines = 5,

page:show()
```

会提示第 20 行附近缺少 `}`，并阻止保存。

### 页面对象缺失

当 `page` 未定义，并且出现 `page:add(...)` 或 `page:show()`，同时当前文件已有 `ui` 引用时，修复器生成：

```lua
local page = ui.page{}
```

插入在第一次 `page` 使用之前；如果文件中没有 `page:show()`，再在文件末尾补：

```lua
page:show()
```

这补齐的是 LuaX-UI 页面对象的最小运行骨架，不会替用户决定标题、导航和业务布局。若当前文件用别名引用 UI 库（例如 `local u = require "luaxplus.ui"`），骨架会写成 `u.page{}`，不强行使用 `ui`。

### 页面忘记 show

当文件里出现任意变量名的页面对象：

```lua
local page = ui.page{
  title = "邮箱和备注",
}
```

但全文没有 `page:show()` 时，审计标记 LX1009，并生成“补页面显示”动作，在文件末尾插入：

```lua
page:show()
```

变量名不要求叫 `page`；`local home = ui.page{}` 会检查 `home:show()`，修复也补 `home:show()`。

### 包装表直接传入容器

LuaX-UI 的 `ui.field` 和 `ui.textArea` 返回的是包装表 `{ view, input }`，真正能传给 `page:add` 的是 `.view`。因此：

```lua
local email = ui.field{ label = "邮箱" }
page:add(email)
```

会标记 LX1010，并生成“改用 email.view”的动作，替换为：

```lua
page:add(email.view)
```

同样的检查适用于任意页面变量名，例如 `home:add(email)`。如果传入的已经是 `email.view`、`email.input`，不会误报。

### 通用规则而不是逐个适配

页面 `show` 和包装表 `.view` 不再写死在审计主循环，而是由两张规则表驱动：

- `objectRules`：某个工厂创建的对象，生命周期里必须调用某个方法。
- `viewWrappers`：某个工厂返回包装表，传给容器时要取某个属性。

自研库可以在初始化时注册规则：

```lua
local lint = require "luaxplus.lint"

lint.registerObjectRule({
  module = "acme.ui",
  factory = "pane",
  kind = "pane",
  requiresMethod = "show",
})

lint.registerViewWrapper({
  module = "acme.ui",
  factory = "input",
  property = "view",
  label = "input",
})
```

注册后，以下代码会自动得到“补 `pane:show()`”和“改用 `name.view`”两个修复：

```lua
local a = require "acme.ui"
local pane = a.pane{}
local name = a.input{ label = "名字" }
pane:add(name)
```

新增同类错误时优先扩展规则表，不再在审计主循环里加一个 `if`。

### 修复流水线

1. 收集用户勾选的动作。
2. 拒绝越界或重叠编辑。
3. 按偏移倒序应用；同一位置插入时 `require` 优先于页面骨架。
4. 用 `load` / `loadstring` 做语法编译。
5. 重新跑同一套审计。
6. 仍有 error、页面对象问题、页面未 show、包装表误传或函数未定义时，不写入文件并展示剩余问题。
7. 成功后保留原文快照，菜单“撤销上次修复”可恢复。

### 修复边界

- 静态修复保证的是“语法可编译、当前规则无 error、可回滚”，不是业务逻辑一定正确。
- 未知全局变量不会凭空创建，避免把真实错误藏起来。
- 修复后如果内容已被手动修改，撤销入口会拒绝恢复，防止覆盖新改动。

## 诊断码

| Code | 含义 |
| --- | --- |
| LX1001 | 已知库缺少 require |
| LX1002 | 未定义全局变量 |
| LX1003 | 未使用局部变量 |
| LX1004 | 局部变量遮蔽 |
| LX1005 | 可能拼写错误 |
| LX1006 | 声明前使用 |
| LX1007 | 页面对象未定义 |
| LX1008 | 函数式全局未定义 |
| LX1009 | 页面已创建但未调用 show |
| LX1010 | 包装表被直接传给容器 |
| LX1011 | 对象已创建但未调用必需方法 |
| LX1012 | Lua 语法错误，阻止保存 |

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
lint     -> luaxplus.lint
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

- 缺引用识别与安全补全。
- 页面骨架、require 与骨架组合顺序。
- 只选择部分修复时的复检阻断。
- 拼写重命名、函数占位与越界回滚。
- 多库合并补全与文件头保留。
- 工程级跨文件定义。
- 自研库清单和目录自动发现。
- 注释、字符串、表键、import、引擎全局不误报。
- 未使用变量、拼写建议、作用域遮蔽和声明前使用。
- 任意页面变量名的 `show` 检查与补全。
- `ui.field` / `ui.textArea` 包装表直接传给 `page:add` 的检测与改 `.view`。
- 自研库注册对象生命周期规则和视图包装规则。
- 语法错误单独报 LX1012、标记阻断且不生成猜测性修复。
