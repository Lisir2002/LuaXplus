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

print("[lint-test] 保存前审计回归通过")
