-- 对 assets 与 resources 中的 Lua 文件做语法编译检查。
-- 只编译不执行，能拦住括号、end、字符串等语法错误，不能替代 JavaAPI 契约测试。

local ROOTS = {
  "app/src/main/assets",
  "app/src/main/resources",
}
local LEGACY_FILE = "tools/lua-check/known-legacy.txt"

local function shellQuote(value)
  return "'" .. value:gsub("'", "'\\''") .. "'"
end

local legacy = {}
local file = io.open(LEGACY_FILE, "r")
if file then
  for raw in file:lines() do
    local line = raw:gsub("\r", "")
    if line ~= "" and not line:match("^#") then
      legacy[line] = true
    end
  end
  file:close()
end

local failures = {}
local checked = 0
local skipped = 0

local function check(path)
  local relative = path:gsub("^%./", "")
  if legacy[relative] then
    skipped = skipped + 1
    return
  end
  checked = checked + 1
  local chunk, message = loadfile(path)
  if not chunk then
    failures[#failures + 1] = message or (path .. ": 未知语法错误")
  end
end

for _, root in ipairs(ROOTS) do
  local pipe = io.popen("find " .. shellQuote(root) .. " -type f -name '*.lua' -print")
  if pipe then
    for path in pipe:lines() do
      check(path)
    end
    pipe:close()
  end
end

if #failures > 0 then
  for _, message in ipairs(failures) do
    io.stderr:write("[lua-check] " .. message .. "\n")
  end
  io.stderr:write(("[lua-check] 语法检查失败：%d 个文件有问题\n"):format(#failures))
  os.exit(1)
end

print(("[lua-check] 语法通过：%d 个文件，跳过 %d 个历史文件"):format(checked, skipped))
for relative in pairs(legacy) do
  print("[lua-check] 已跳过历史文件：" .. relative)
end
