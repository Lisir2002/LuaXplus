luajava = {
  bindClass = function(name)
    assert(name == "android.icu.text.Transliterator", "意外的 ICU 类：" .. tostring(name))
    return {
      getInstance = function(id)
        assert(id == "Han-Latin; Latin-ASCII", "意外的转写规则：" .. tostring(id))
        return {
          transliterate = function(value)
            local map = {
              ["记账本"] = "ji zhang ben",
              ["报表"] = "bao biao",
            }
            return map[value] or value
          end,
        }
      end,
    }
  end,
}
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
assert(pkgname.pinyin("记账本") == "ji zhang ben", "中文没有转成拼音")
assert(pkgname.slug("记账本") == "ji_zhang_ben", pkgname.slug("记账本"))
assert(pkgname.slug("报表") == "bao_biao", pkgname.slug("报表"))
assert(#pkgname.slug(string.rep("A", 80)) <= 32, "包名段过长")

valid(pkgname.generate("My Notes", {}))
assert(pkgname.generate("Notes", {}) == "com.mini.notes")

local used = { ["com.mini.notes"] = true, ["com.mini.notes_2"] = true }
local generated = pkgname.generate("Notes", used)
assert(generated == "com.mini.notes_3", "重复包名未递增：" .. generated)
valid(generated)

local generatedChinese = pkgname.generate("记账本", {})
valid(generatedChinese)
assert(generatedChinese == "com.mini.ji_zhang_ben", generatedChinese)

-- ICU 不可用时仍必须给出合法的哈希兜底包名。
luajava.bindClass = function()
  return nil
end
local fallback = assert(loadfile("app/src/main/assets/lua/luaxplus/pkgname.lua"))()
assert(fallback.pinyin("记账本") == nil, "ICU 不可用时不应返回拼音")
local fallbackPackage = fallback.generate("记账本", {})
valid(fallbackPackage)
assert(fallbackPackage:match("^com%.mini%.app%d+$"), fallbackPackage)

print("[lua-smoke] 包名自动生成通过")
