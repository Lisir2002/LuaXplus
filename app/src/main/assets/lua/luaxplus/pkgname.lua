-- 把应用名称转成合法的 Android 包名。
-- 规则：每段只允许小写字母和数字；每段以字母开头；总长度可控。
-- 包名不强制使用下划线，这里用连续小写字母，阅读更干净。
local M = {}

local function trim(value)
  return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function stableHash(value)
  local hash = 0
  for index = 1, #value do
    hash = (hash * 131 + value:byte(index)) % 2147483647
  end
  return tostring(hash)
end

local transliterator
local transliteratorChecked = false

local function getTransliterator()
  if transliteratorChecked then
    return transliterator
  end
  transliteratorChecked = true

  local luajava = rawget(_G, "luajava")
  if not luajava then
    return nil
  end
  local loaded, class = pcall(luajava.bindClass, "android.icu.text.Transliterator")
  if not loaded or not class then
    return nil
  end
  local created, instance = pcall(function()
    -- Latin-ASCII 去掉声调符号，直接得到可进包名的拉丁字母
    return class.getInstance("Han-Latin; Latin-ASCII")
  end)
  if created and instance then
    transliterator = instance
  end
  return transliterator
end

-- 中文转拼音；Android 10+ 使用系统 ICU。低版本或类不可用时返回 nil，
-- 由 slug 的哈希兜底，仍然保证包名合法。
function M.pinyin(value)
  local instance = getTransliterator()
  if not instance then
    return nil
  end
  local ok, result = pcall(function()
    return instance.transliterate(tostring(value or ""))
  end)
  if not ok or not result then
    return nil
  end
  result = tostring(result)
  if result == "" then
    return nil
  end
  return result
end

function M.slug(name)
  name = trim(name)
  local pinyin = M.pinyin(name)
  local source = pinyin or name
  local slug = source:lower():gsub("[^a-z0-9]+", "")

  -- 拼音不可用、纯符号或空名称没有可用的 ASCII 字符，用稳定哈希保证可重复。
  if slug == "" then
    slug = "app" .. stableHash(name)
  elseif not slug:match("^[a-z]") then
    slug = "app" .. slug
  end

  if #slug > 32 then
    slug = slug:sub(1, 32)
  end
  return slug
end

-- used 是已有包名集合，返回第一个不冲突的包名。
function M.generate(name, used)
  local base = "com.mini." .. M.slug(name)
  if not used or not used[base] then
    return base
  end

  local index = 2
  local candidate = base .. ".v" .. index
  while used[candidate] do
    index = index + 1
    candidate = base .. ".v" .. index
  end
  return candidate
end

return M
