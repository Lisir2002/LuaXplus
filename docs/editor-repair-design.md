# 编辑器一键修复设计规范

## 1. 目标与边界

目标不是“任何报错都自动塞一行代码”，而是把常见运行期 nil 问题变成可解释、可预览、可回滚的修复流程。

需要明确区分两种保证：

- **可以保证**：应用修复后 Lua 语法可编译；当前审计规则下 error 归零；每次修改都有预览和回滚点。
- **不能保证**：业务逻辑一定正确、页面一定符合设计、设备上一定不崩。静态分析无法知道 `page` 想放在哪个位置、标题是什么，也无法执行用户工程。

因此“确保每次可用”落地为四道门：

1. 只自动应用无歧义的修复。
2. 有歧义的修复必须展示候选和预览。
3. 应用后立即做语法编译和重新审计。
4. 复检失败自动回滚，不写入损坏文件。

## 2. 参考设计

- LSP 的 code action 把修复绑定到稳定诊断码，`source.fixAll` 只应用明确安全的修复，避免猜测歧义。[gopls](https://tip.golang.org/gopls/features/transformation)
- IntelliJ 对未声明变量会同时给出“创建局部变量 / 创建字段 / 重命名引用”等多个意图，并要求用户选择，不静默替用户决定。[IntelliJ](https://www.jetbrains.com/help/idea/intention-actions.html)
- luacheck 把“访问未定义全局变量”作为单独诊断，允许通过工程配置声明合法全局，而不是自动创建变量。[luacheck](https://luacheck.readthedocs.io/en/stable/warnings.html)
- 保守自动修复框架会在修复时重新获取动作，跳过零个或多个候选的歧义项，并限制单次修复数量。[pi-lens](http://www.shturl.cc/809fa05e29d1924604146b26a9bdd41b)

## 3. 诊断码

现有审计问题增加稳定 code，供修复器、测试和后续自研库匹配：

| Code | 含义 | 默认级别 |
| --- | --- | --- |
| LX1001 | 已知库缺少 require | error |
| LX1002 | 未定义全局变量 | warning |
| LX1003 | 未使用局部变量 | info |
| LX1004 | 局部变量遮蔽 | info |
| LX1005 | 可能的拼写错误 | warning |
| LX1006 | 声明前使用 | warning/info |
| LX1007 | 页面对象未定义 | warning |
| LX1008 | 函数式全局未定义 | warning |

## 4. 修复动作模型

每个问题可以产生 0 到多个 `CodeAction`：

```lua
{
  code = "LX1001",
  title = "补全 ui 引用",
  confidence = "safe",          -- safe | guided | manual
  kind = "quickfix",            -- quickfix | refactor | source.fixAll
  edits = {
    { startOffset = 0, endOffset = 0, text = 'local ui = require "luaxplus.ui"\n' },
  },
  preview = "在文件头插入 1 行 require",
  postCheck = true,
}
```

置信度定义：

- `safe`：语义唯一，可以直接一键应用。例如补 `require`。
- `guided`：能生成可运行代码，但需要用户确认模板内容。例如创建 `page` 骨架、函数占位。
- `manual`：无法可靠推断，只解释原因，不给自动修复。例如动态 `_G[name]`、未知字段、业务变量。

## 5. 修复目录

| 问题 | 修复动作 | 置信度 | 说明 |
| --- | --- | --- | --- |
| 缺少已知库 require | 插入 `local x = require "module"` | safe | 优先插在文件头注释之后、第一个代码行之前 |
| `page:add` / `page:show` 但 page 未定义 | 插入 `local page = ui.page{}`；必要时补 `page:show()` | guided | 从调用形态推断为 LuaX-UI 页面对象 |
| 未定义函数式全局 `foo(` | 插入 `local function foo(...) end` | guided | 只保证不再 nil，函数体需要用户补 |
| 未定义表式全局 `foo.bar` | 插入 `local foo = {}` 或提示手动声明 | guided/manual | 只有后续是赋值/表访问时才生成空表 |
| 拼写相近的未定义变量 | 重命名为候选符号 | guided | 预览所有受影响位置，不能静默改 |
| 未使用局部变量 | 前缀 `_` 或保留 | guided | 右侧有函数调用时不移除声明，避免丢副作用 |
| 局部遮蔽 | 重命名内层变量及其作用域内引用 | guided | 需要作用域感知 |
| 动态全局 / 通配符 import | 只提示，不生成变量 | manual | 避免把真实业务错误隐藏掉 |

### page 场景的具体规则

当同时满足：

- `page` 未解析；
- `page` 被 `:` 调用，方法名包含 `add` 或 `show`；
- 当前文件已引用 `ui`，或 `ui` 是已知库；

生成两条编辑：

```lua
local page = ui.page{}
```

插入在第一次 `page` 使用之前；如果文件中没有 `page:show()`，再追加：

```lua
page:show()
```

预览会显示两处修改。用户可以取消 `page:show()`，只保留页面对象。

这不是“猜测业务”，而是补齐 LuaX-UI 页面对象的最小可运行骨架。标题、导航、主题等仍由用户填写。

## 6. 应用流水线

```text
诊断
  -> 生成候选 CodeAction
  -> 过滤重叠编辑
  -> 用户选择（safe 默认选中，guided 默认不选）
  -> 倒序应用偏移
  -> load() 编译检查
  -> 重新 audit()
  -> 仍有 error：回滚并展示失败原因
  -> 无 error：写入编辑器，保留撤销快照
```

### 防止破坏文件

- 所有编辑使用绝对偏移，应用前校验偏移是否仍在原文范围内。
- 多个编辑重叠时拒绝自动修复，改为逐项让用户选择。
- 应用前保存原文快照；复检失败恢复快照。
- 单次最多应用 8 个动作，避免一次改太多。
- 修复后必须重跑同一套审计，不能只相信补丁本身。

### 撤销

编辑器保留最近一次修复的：

```lua
{
  before = "原始全文",
  after = "修复后全文",
  actions = { ... },
}
```

修复结果弹窗提供“撤销本次修复”；用户手动编辑后快照失效，避免误回滚。

## 7. 保存前交互

### 只有 safe 动作

弹窗按钮：

- 一键修复并保存
- 仍然保存
- 取消

### 有 guided 动作

点击“查看修复方案”打开二级列表：

- 每条动作显示标题、置信度、修改预览；
- safe 默认勾选，guided 默认不勾选；
- 底部“应用选中项并保存”；
- 仍保留“仍然保存 / 取消”。

### 没有可自动修复项

不显示“一键修复”，明确说明：

> 当前问题没有安全自动修复项。`page` 需要先声明为页面对象，不能凭空创建业务变量。

## 8. 自研库修复提供者

修复器不能把 `ui.page` 写死在核心。自研库可以注册：

```lua
local repair = require "luaxplus.repair"

repair.registerProvider({
  code = "LX1002",
  name = "page",
  match = function(issue, context)
    return issue.name == "page" and context.hasMemberCall("add")
  end,
  build = function(issue, context)
    return {
      title = "插入页面骨架",
      confidence = "guided",
      edits = { ... },
    }
  end,
})
```

库也可以只注册“修复模板”：

```lua
repair.registerTemplate("page", {
  declaration = "local page = ui.page{}",
  showCall = "page:show()",
})
```

审计负责发现问题，修复器负责生成候选，库负责解释自己的对象结构。

## 9. 验收标准

- `page:add` 未定义场景：一键方案生成 `local page = ui.page{}`，应用后审计无 error，语法可编译。
- 缺少 `ui` require：一键补全后无 error。
- 未知 `foo.bar` 无可靠候选时：不生成自动修复，只显示手动说明。
- 修复产生语法错误：自动回滚，文件保持原文。
- 修复后仍有 error：不写入磁盘，弹窗显示剩余问题。
- 所有动作有偏移边界测试、重叠测试、回滚测试。
- 自研库 provider 注册后无需修改审计核心即可出现对应修复。
