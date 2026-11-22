local pkgname = assert(loadfile("app/src/main/assets/lua/luaxplus/pkgname.lua"))()

local function valid(package)
  assert(package:match("^[a-z][a-z0-9_.]*$"), "非法包名：" .. package)
  for segment in package:gmatch("[^.]+") do
    assert(segment:match("^[a-z][a-z0-9_]*$"), "非法包名段：" .. package)
  end
end

assert(pkgname.slug("My Notes") == "my_notes", pkgname.slug("My Notes"))
assert(pkgname.slug("123") == "app_123", pkgname.slug("123"))
assert(pkgname.slug("!!!"):match("^app%d+$"), "纯符号名称未生成哈希")
assert(pkgname.slug("记账本"):match("^app%d+$"), "中文名称未生成哈希")
assert(pkgname.slug("记账本") ~= pkgname.slug("报表"), "不同中文名称生成了相同包名")
assert(#pkgname.slug(string.rep("A", 80)) <= 32, "包名段过长")

valid(pkgname.generate("My Notes", {}))
assert(pkgname.generate("Notes", {}) == "com.mini.notes")

local used = { ["com.mini.notes"] = true, ["com.mini.notes_2"] = true }
local generated = pkgname.generate("Notes", used)
assert(generated == "com.mini.notes_3", "重复包名未递增：" .. generated)
valid(generated)

local generatedChinese = pkgname.generate("记账本", {})
valid(generatedChinese)
assert(generatedChinese:find("com.mini.app", 1, true), generatedChinese)

print("[lua-smoke] 包名自动生成通过")
