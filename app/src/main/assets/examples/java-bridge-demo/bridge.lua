-- 双向示例的 Lua 侧函数。此文件不创建界面，由 Java 入口加载后挂到 LuaBridge。
function getLuaMessage()
  return "Lua 页面问候：双向桥已连通"
end

function onJavaMessage(value)
  return "Lua 已处理：" .. tostring(value)
end
