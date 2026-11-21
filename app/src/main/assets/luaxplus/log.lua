-- Mini-LuaXPLUS 日志模块：把 Lua 侧事件写入外部存储 LuaXPlus/logs
-- 任何写日志动作都包了 pcall，日志本身不能影响业务运行

local LogCore = luajava.bindClass("com.mini.luaxplus.LogCore")

local M = {}
local installed = false
local importWrapped = false

local function flatten(...)
  local count = select("#", ...)
  local parts = {}
  for index = 1, count do
    local value = select(index, ...)
    local kind = type(value)
    if kind == "string" then
      parts[#parts + 1] = value
    elseif kind == "nil" then
      parts[#parts + 1] = "nil"
    elseif kind == "table" then
      parts[#parts + 1] = "table(" .. tostring(value) .. ")"
    else
      local ok, text = pcall(tostring, value)
      parts[#parts + 1] = ok and text or ("<" .. kind .. ">")
    end
  end
  return table.concat(parts, " ")
end

local function write(level, tag, ...)
  local ok, text = pcall(flatten, ...)
  if not ok then
    return
  end
  pcall(function()
    if level == "E" then
      LogCore.e(tostring(tag), text)
    elseif level == "W" then
      LogCore.w(tostring(tag), text)
    elseif level == "D" then
      LogCore.d(tostring(tag), text)
    else
      LogCore.i(tostring(tag), text)
    end
  end)
end

function M.i(tag, ...)
  write("I", tag, ...)
end

function M.w(tag, ...)
  write("W", tag, ...)
end

function M.e(tag, ...)
  write("E", tag, ...)
end

function M.d(tag, ...)
  write("D", tag, ...)
end

-- 记录 Lua 错误与堆栈，落到独立的 luaerror 文件
function M.err(source, message, traceback)
  pcall(function()
    LogCore.luaError(tostring(source) .. ": " .. tostring(message), tostring(traceback or ""))
  end)
end

-- 日志目录，便于在界面提示用户去哪里取日志
function M.dir()
  local ok, value = pcall(function()
    return LogCore.dir()
  end)
  return ok and value or ""
end

-- 接管 print，让控制台输出同时落盘
function M.install()
  if installed then
    return
  end
  installed = true
  local rawPrint = print
  print = function(...)
    write("I", "print", ...)
    return rawPrint(...)
  end
  M.i("Log", "Lua 日志已接管 print")
end

-- 包装 import，记录每次模块与类导入；需在 require "import" 之后调用
function M.wrapImport()
  if importWrapped then
    return
  end
  local rawImport = import
  if type(rawImport) ~= "function" then
    M.w("Log", "import 不是函数，跳过包装")
    return
  end
  importWrapped = true
  import = function(...)
    write("D", "import", ...)
    return rawImport(...)
  end
  M.i("Log", "import 调用已纳入日志")
end

-- 包装指定函数，异常时记录堆栈并继续抛出，供关键操作使用
function M.guard(name, handler)
  return function(...)
    local ok, message = pcall(handler, ...)
    if not ok then
      local trace = debug.traceback("", 2)
      M.err(name, message, trace)
      error(message, 0)
    end
    return message
  end
end

return M
