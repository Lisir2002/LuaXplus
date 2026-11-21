-- 入口保护层：接管日志并统一捕获 Lua 层错误，记录后再交回运行时展示
local log
pcall(function()
  log = require "luaxplus.log"
  log.install()
end)

local function record(err)
  local trace = debug.traceback(tostring(err), 2)
  if log then
    log.err("main", tostring(err), trace)
  end
  return trace
end

if log then
  log.i("boot", "入口脚本开始加载")
end

local ok, result = xpcall(function()
  return require "mainbody"
end, record)

if not ok then
  if log then
    log.e("boot", "入口脚本加载失败，已写入 luaerror 日志")
  end
  error(tostring(result), 0)
end

return result
