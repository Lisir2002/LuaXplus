-- 打包前预检：只读工程目录，不执行工程代码。
-- 检查 main.lua 是否存在，以及所有 Lua / .aly 文件能否通过语法编译。
-- JavaAPI 这类运行期契约错误不在这里检查，仍需靠 tools/lua-smoke 的契约测试。

local M = {}

local function relativePath(path, root)
  if root == "" then
    return path
  end
  if path:sub(1, #root + 1) == root .. "/" then
    return path:sub(#root + 2)
  end
  return path
end

local function cleanError(error)
  local text = tostring(error or "未知错误")
  text = text:gsub("\r", "")
  text = text:gsub("\n", " ")
  return text
end

local function sourceError(path, label, error)
  return label .. " " .. path .. "：" .. cleanError(error)
end

local function checkLayout(path, name, relative, errors)
  local handle = io.open(path, "r")
  if not handle then
    errors[#errors + 1] = sourceError(relative, "布局读取失败", name)
    return
  end
  local source = handle:read("*a") or ""
  handle:close()

  local compile = loadstring or load
  local chunk, errorMessage = compile("local layout=" .. source .. "\nreturn layout", name)
  if not chunk then
    errors[#errors + 1] = sourceError(relative, "布局语法错误", errorMessage)
  end
end

local function scan(File, path, root, errors)
  local directory = File(path)
  local children = directory.listFiles()
  if not children then
    return
  end

  for index = 0, #children - 1 do
    local child = children[index]
    if child then
      local name = child.getName()
      if name and name ~= "" and name:sub(1, 1) ~= "." then
        local childPath = child.getPath() or (path .. "/" .. name)
        local lower = name:lower()
        if child.isDirectory() then
          scan(File, childPath, root, errors)
        elseif lower:match("%.lua$") then
          local chunk, errorMessage = loadfile(childPath)
          if not chunk then
            errors[#errors + 1] = sourceError(relativePath(childPath, root), "Lua 语法错误", errorMessage)
          end
        elseif lower:match("%.aly$") then
          checkLayout(childPath, name, relativePath(childPath, root), errors)
        end
      end
    end
  end
end

-- 返回 nil 表示通过；返回字符串数组表示发现的问题。
function M.check(root)
  root = tostring(root or ""):gsub("/+$", "")
  local File = luajava.bindClass("java.io.File")
  local directory = File(root)
  if not directory.exists() or not directory.isDirectory() then
    return { "工程目录不存在：" .. tostring(root) }
  end

  local errors = {}
  local entry = File(root .. "/main.lua")
  if not entry.exists() then
    errors[#errors + 1] = "缺少入口文件 main.lua"
  end

  scan(File, root, root, errors)
  table.sort(errors)
  if #errors == 0 then
    return nil
  end
  return errors
end

return M
