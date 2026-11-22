-- 把应用名称转成合法的 Android 包名。
-- 规则：每段只允许小写字母、数字、下划线；每段以字母开头；总长度可控。
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

function M.slug(name)
  name = trim(name)
  local slug = name:lower()
    :gsub("[^a-z0-9_]+", "_")
    :gsub("_+", "_")
    :gsub("^_", "")
    :gsub("_$", "")

  -- 纯中文、符号或空名称没有可用的 ASCII 字符，用稳定哈希保证可重复。
  if slug == "" then
    slug = "app" .. stableHash(name)
  elseif not slug:match("^[a-z]") then
    slug = "app_" .. slug
  end

  if #slug > 32 then
    slug = slug:sub(1, 32):gsub("_$", "")
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
  local candidate = base .. "_" .. index
  while used[candidate] do
    index = index + 1
    candidate = base .. "_" .. index
  end
  return candidate
end

return M
