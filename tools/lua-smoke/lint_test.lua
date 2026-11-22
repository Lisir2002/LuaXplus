-- 保存前 Lua 审计的回归测试。
-- 只测纯 Lua 分析逻辑，不依赖 Android 界面；真实弹窗由编辑器在设备上承载。

package.path = "./app/src/main/assets/lua/?.lua;" .. package.path
local lint = require "luaxplus.lint"

local function fail(message)
  error("[lint-test] " .. message, 2)
end

local function expect(condition, message)
  if not condition then
    fail(message)
  end
end

local function quote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function write(path, content)
  local file = assert(io.open(path, "wb"))
  file:write(content)
  file:close()
end

local function issueKinds(report)
  local kinds = {}
  for _, issue in ipairs(report.issues) do
    kinds[issue.kind] = true
  end
  return kinds
end

local function cleanup(root)
  os.execute("rm -rf " .. quote(root))
end

local function makeRoot()
  local root = os.tmpname()
  os.remove(root)
  local ok = os.execute("mkdir -p " .. quote(root))
  assert(ok == true or ok == 0)
  return root
end

lint.resetLibraries()

-- 注释、字符串、长字符串和表键不能被当成引用。
local quiet = lint.audit([[
-- ui.show{} 只在注释里
local s = "ui.show{}"
local long = [=[ ui.show{} ]=]
local t = { ui = 1 }
print(s, long, t)
]], { file = "main.lua" })
expect(#quiet.issues == 0, "注释、字符串或表键出现了误报")

-- 缺少 ui 引用时给出 error，并生成一条可应用补丁。
local missing = lint.audit("ui.show{\n  title = 'x'\n}\n", { file = "main.lua" })
expect(issueKinds(missing).missing_require, "没有识别出缺少 ui 引用")
expect(#missing.fixes == 1, "缺少引用没有生成补全补丁")
local fixed, applied = lint.applyFixes("ui.show{\n  title = 'x'\n}\n", missing)
expect(applied == 1, "补全补丁没有应用")
expect(fixed:match('^local ui = require "luaxplus%.ui"'), "补全内容不是 ui require")
local afterFix = lint.audit(fixed, { file = "main.lua" })
expect(#afterFix.issues == 0, "补全后仍然报告缺少 ui 引用")

-- 已正确引用时不能重复提示。
local existing = lint.audit("local ui = require \"luaxplus.ui\"\nui.show{}\n", { file = "main.lua" })
expect(#existing.issues == 0, "正确引用仍被误报")

-- 同一文件多个已知库引用，一键补全要合并插入，并保留文件头注释。
lint.registerLibrary({ name = "net", module = "acme.net" })
lint.registerLibrary({ name = "json", module = "acme.json" })
local multi = lint.audit("-- header\n\nnet.get()\njson.decode('x')\n", { file = "main.lua" })
expect(#multi.fixes == 2, "多个库引用没有生成两条补全")
local multiFixed, multiApplied = lint.applyFixes("-- header\n\nnet.get()\njson.decode('x')\n", multi)
expect(multiApplied == 2, "多个库引用没有全部应用")
expect(multiFixed:match("^%-%- header\n\nlocal json"), "补全没有保留文件头注释")
expect(multiFixed:match('local net = require "acme%.net"'), "net 补全缺失")
expect(multiFixed:match('local json = require "acme%.json"'), "json 补全缺失")

lint.resetLibraries()

-- 工程级索引：另一个文件里的全局函数应被识别。
local root = makeRoot()
write(root .. "/other.lua", "function helper()\n  return 1\nend\n")
local indexed = lint.audit("helper()\n", { file = root .. "/main.lua", projectRoot = root })
expect(not issueKinds(indexed).undefined_global, "工程级定义没有生效")
cleanup(root)

-- 项目 lua/ 下的自研库应自动注册，并按文件路径生成 require。
root = makeRoot()
os.execute("mkdir -p " .. quote(root .. "/lua/acme"))
write(root .. "/lua/acme/net.lua", "return {}\n")
local discovered = lint.audit("net.get()\n", { file = root .. "/main.lua", projectRoot = root })
expect(issueKinds(discovered).missing_require, "自研库没有被自动发现")
expect(#discovered.fixes == 1, "自研库没有生成补全")
expect(discovered.fixes[1].text == 'local net = require "acme.net"', "自研库 require 路径不对")
cleanup(root)

-- 显式清单适合库名和路径不一致的自研库。
root = makeRoot()
os.execute("mkdir -p " .. quote(root .. "/lua"))
write(root .. "/lua/lint-libs.lua", 'return { { name = "remote", module = "acme.remote" } }\n')
local manifest = lint.audit("remote.fetch()\n", { file = root .. "/main.lua", projectRoot = root })
expect(#manifest.fixes == 1, "清单注册没有生成补全")
expect(manifest.fixes[1].text == 'local remote = require "acme.remote"', "清单 require 路径不对")
cleanup(root)

-- 未知全局只提示，不自动修改；相近拼写给出建议。
local unknown = lint.audit("foo.bar()\n", { file = "main.lua" })
expect(issueKinds(unknown).undefined_global, "未知全局没有提示")
expect(#unknown.fixes == 0, "未知全局不应自动补全")
local typo = lint.audit("prin('x')\n", { file = "main.lua" })
expect(issueKinds(typo).possible_typo, "拼写错误没有提示")
expect(#typo.fixes == 0, "拼写错误不应自动补全")

-- 未使用局部变量和作用域遮蔽属于更细提示。
local unused = lint.audit("local x = 1\nprint(1)\n", { file = "main.lua" })
expect(issueKinds(unused).unused_local, "未使用局部变量没有提示")
local shadow = lint.audit(
  "local ui = require \"luaxplus.ui\"\nlocal function f()\n  local ui = 1\n  return ui\nend\nf()\n",
  { file = "main.lua" }
)
expect(issueKinds(shadow).shadow, "作用域遮蔽没有提示")

-- if / elseif 分支各自有局部作用域，分支里的同名变量不能互相覆盖。
local branches = lint.audit([[
local function f(action)
  if action == "a" then
    local box = 1
    print(box)
  elseif action == "b" then
    local box = 2
    print(box)
  end
end
f("a")
]], { file = "main.lua" })
expect(not issueKinds(branches).undefined_global, "if 分支局部变量没有正确解析")

-- 引擎全局和 import 后的类名不能误报。
local engine = lint.audit("activity.setTitle('x')\nprint('ok')\n", { file = "main.lua" })
expect(#engine.issues == 0, "引擎全局被误报")
local imported = lint.audit("import \"com.demo.MyView\"\nMyView()\n", { file = "main.lua" })
expect(#imported.issues == 0, "import 后的全局类名被误报")

-- 声明在使用之后属于 late_local，不自动插入重复 require。
local late = lint.audit("ui.show{}\nlocal ui = require \"luaxplus.ui\"\n", { file = "main.lua" })
expect(issueKinds(late).late_local, "声明前使用没有提示")
expect(#late.fixes == 0, "声明前使用不应重复补全")

-- page:add 未定义时生成页面骨架，并在复检通过后才算修复成功。
local pageSource = [[local ui = require "luaxplus.ui"

local email = ui.field{
  label = "邮箱",
}

page:add(email.view)
]]
local pageReport = lint.audit(pageSource, { file = "main.lua" })
expect(issueKinds(pageReport).page_object, "page 未定义没有识别成页面对象问题")
expect(pageReport.issues[1].code == "LX1007", "page 问题没有稳定的诊断码")
expect(#pageReport.actions == 1, "page 未定义没有生成修复动作")
local pageAction = pageReport.actions[1]
expect(pageAction.code == "LX1007", "页面骨架动作诊断码不对")
expect(#pageAction.edits == 2, "页面骨架应同时插入声明和 show")
local pageResult = lint.applyRepair(pageSource, pageReport)
expect(pageResult.ok, "页面骨架修复没有通过复检")
expect(pageResult.text:match("local page = ui%.page%{%}"), "页面骨架没有插入 page 声明")
expect(pageResult.text:match("page:show%(%)"), "页面骨架没有补 page:show")
local pageAfter = lint.audit(pageResult.text, { file = "main.lua" })
expect(#pageAfter.issues == 0, "页面骨架修复后仍有问题")

-- 同时缺 ui 和 page 时，require 必须排在页面骨架前面。
local missingBoth = lint.audit("page:add(ui.text{ text = 'x' })\n", { file = "main.lua" })
expect(#missingBoth.actions == 2, "缺 ui 和 page 没有生成两个修复动作")
local bothResult = lint.applyRepair("page:add(ui.text{ text = 'x' })\n", missingBoth)
expect(bothResult.ok, "缺 ui 和 page 的组合修复没有通过")
expect(bothResult.text:match('^local ui = require "luaxplus%.ui"\nlocal page'),
  "页面骨架插到了 ui require 前面")

-- 只选择 safe 的 require、不选择 page 骨架时，不允许把半成品写回。
local requireOnly
for _, action in ipairs(missingBoth.actions) do
  if action.code == "LX1001" then
    requireOnly = action
  end
end
expect(requireOnly ~= nil, "缺 ui 场景没有 safe require 动作")
local partial = lint.applyRepair("page:add(ui.text{ text = 'x' })\n", missingBoth, {
  actions = { requireOnly },
})
expect(not partial.ok, "只修 require 仍留下 page 未定义，复检却通过了")
expect(partial.reason == "lint", "部分修复没有以 lint 原因阻断")

-- 页面对象已经创建但忘记 show 时，也要提示并补在文件末尾。
local pageDefined = [[local ui = require "luaxplus.ui"
local page = ui.page{
  title = "邮箱和备注",
}
local email = ui.field{ label = "邮箱" }
page:add(email.view, 12)
]]
local pageDefinedReport = lint.audit(pageDefined, { file = "main.lua" })
expect(issueKinds(pageDefinedReport).page_not_shown, "已创建页面但没有 show 时没有提示")
expect(pageDefinedReport.issues[1].code == "LX1009", "page_not_shown 诊断码不对")
expect(#pageDefinedReport.actions == 1, "page_not_shown 没有生成修复动作")
local pageDefinedResult = lint.applyRepair(pageDefined, pageDefinedReport)
expect(pageDefinedResult.ok, "page:show 补全没有通过复检")
expect(pageDefinedResult.text:match("page:show%(%)"), "page:show 没有补到文件末尾")
local pageDefinedAfter = lint.audit(pageDefinedResult.text, { file = "main.lua" })
expect(#pageDefinedAfter.issues == 0, "补 page:show 后仍有问题")

local alreadyShown = lint.audit(pageDefined .. "page:show()\n", { file = "main.lua" })
expect(not issueKinds(alreadyShown).page_not_shown, "已有 page:show 时不应重复提示")

-- 任意变量名的页面对象都要检查 show，不再只认 page。
local homePage = [[local ui = require "luaxplus.ui"
local home = ui.page{ title = "首页" }
home:add(ui.text{ text = "你好" }.view)
]]
local homeReport = lint.audit(homePage, { file = "main.lua" })
expect(issueKinds(homeReport).page_not_shown, "自定义页面变量名没有检查 show")
expect(homeReport.actions[1].title:match("home"), "页面动作没有使用实际变量名")
local homeResult = lint.applyRepair(homePage, homeReport)
expect(homeResult.ok and homeResult.text:match("home:show%(%)"), "自定义页面没有补 home:show")

-- field 包装表直接传给 page:add 时，自动改为 email.view。
local wrapperSource = [[local ui = require "luaxplus.ui"
local page = ui.page{}
local email = ui.field{ label = "邮箱" }
page:add(email, 12)
page:show()
]]
local wrapperReport = lint.audit(wrapperSource, { file = "main.lua" })
expect(issueKinds(wrapperReport).view_wrapper, "field 包装表传给 page:add 没有提示")
expect(wrapperReport.issues[1].code == "LX1010", "view_wrapper 诊断码不对")
local wrapperResult = lint.applyRepair(wrapperSource, wrapperReport)
expect(wrapperResult.ok and wrapperResult.text:match("page:add%(email%.view, 12%)"),
  "包装表没有改成 email.view")
local wrapperAfter = lint.audit(wrapperResult.text, { file = "main.lua" })
expect(#wrapperAfter.issues == 0, "改为 email.view 后仍有问题")

-- 自研库可以注册对象生命周期和视图包装规则，不用改审计核心。
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
local customSource = [[local a = require "acme.ui"
local pane = a.pane{}
local name = a.input{ label = "名字" }
pane:add(name)
]]
local customReport = lint.audit(customSource, { file = "main.lua" })
expect(issueKinds(customReport).object_not_called, "自研对象生命周期规则没有生效")
expect(issueKinds(customReport).view_wrapper, "自研视图包装规则没有生效")
local customResult = lint.applyRepair(customSource, customReport)
expect(customResult.ok, "自研库规则生成的修复没有通过复检")
expect(customResult.text:match("pane:add%(name%.view%)"), "自研包装表没有改成 name.view")
expect(customResult.text:match("pane:show%(%)"), "自研对象没有补 pane:show")

-- 未知表成员不生成自动修复，避免凭空创建错误对象。
local ambiguous = lint.audit("foo.bar()\n", { file = "main.lua" })
expect(#ambiguous.actions == 0, "未知表成员不应生成自动修复")

-- 明确拼写错误可以给出重命名动作。
local typoFix = lint.audit("prin('x')\n", { file = "main.lua" })
expect(#typoFix.actions == 1, "拼写错误没有生成重命名动作")
expect(typoFix.actions[1].confidence == "guided", "拼写重命名应是需确认动作")
local typoResult = lint.applyRepair("prin('x')\n", typoFix)
expect(typoResult.ok and typoResult.text == "print('x')\n", "拼写重命名没有正确应用")

-- 未定义函数可以生成空函数占位，但仍标记为需确认。
local functionFix = lint.audit("foo()\n", { file = "main.lua" })
expect(#functionFix.actions == 1, "未定义函数没有生成占位动作")
local functionResult = lint.applyRepair("foo()\n", functionFix)
expect(functionResult.ok, "函数占位修复没有通过复检")
expect(functionResult.text:match("local function foo%(%.%.%.%)"), "函数占位内容不对")

-- 越界编辑必须拒绝，并保持原文。
local badReport = lint.audit("print('x')\n", { file = "main.lua" })
local badResult = lint.applyRepair("print('x')\n", badReport, {
  actions = {
    {
      code = "LX9999",
      name = "bad",
      edits = { { startOffset = 999, endOffset = 999, text = "x" } },
    },
  },
})
expect(not badResult.ok and badResult.text == "print('x')\n", "越界修复没有回滚")

print("[lint-test] 保存前审计回归通过")
