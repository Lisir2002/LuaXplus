local M = {}

local Compiler
local Runtime
local Build

local function bindClasses()
  if not Compiler then
    Compiler = luajava.bindClass("com.mini.luaxplus.java.JavaProjectCompiler")
    Runtime = luajava.bindClass("com.mini.luaxplus.java.JavaRuntime")
  end
  if not Build then
    Build = luajava.bindClass("android.os.Build")
  end
end

local function supported()
  bindClasses()
  return Build.VERSION.SDK_INT >= 26
end

local function unsupported()
  return {
    success = false,
    message = "手机内编译需要 Android 8.0 及以上系统",
  }
end

local function toResult(result)
  if not result then
    return { success = false, message = "编译器没有返回结果" }
  end
  return {
    success = result.success,
    message = result.message,
    dexPath = result.dexPath,
    classDir = result.classDir,
  }
end

-- 编译 assets/examples/<project>/src 下的 Java 工程。
function M.compileAsset(project)
  if not supported() then
    return unsupported()
  end
  local result = Compiler.compileAssetProject(
    activity,
    "examples/" .. project .. "/src",
    project
  )
  return toResult(result)
end

-- 编译指定目录中的 Java 工程。
function M.compile(sourceDir, outputDir)
  if not supported() then
    return unsupported()
  end
  local result = Compiler.compile(activity, sourceDir, outputDir)
  return toResult(result)
end

-- 后台编译指定目录；callback 在界面线程收到结果表。
function M.compileAsync(sourceDir, outputDir, callback)
  if not supported() then
    local result = unsupported()
    if callback then
      callback(result)
    end
    return
  end
  local proxy = luajava.createProxy(
    "com.mini.luaxplus.java.JavaCompileCallback",
    {
      onResult = function(result)
        if callback then
          callback(toResult(result))
        end
      end,
    }
  )
  Compiler.compileAsync(activity, sourceDir, outputDir, proxy)
end

-- 后台编译 assets 示例工程；callback 在界面线程收到结果表。
function M.compileAssetAsync(project, callback)
  if not supported() then
    local result = unsupported()
    if callback then
      callback(result)
    end
    return
  end
  local proxy = luajava.createProxy(
    "com.mini.luaxplus.java.JavaCompileCallback",
    {
      onResult = function(result)
        if callback then
          callback(toResult(result))
        end
      end,
    }
  )
  Compiler.compileAssetProjectAsync(
    activity,
    "examples/" .. project .. "/src",
    project,
    proxy
  )
end

-- 打开已经存在的 Java 页面；dexPath 为空时使用 APK 内置的 classes.dex。
function M.run(screenClass, dexPath, argument)
  bindClasses()
  local state = activity.getLuaState()
  if state == nil then
    return false, "当前页面没有 LuaState"
  end
  local token = Runtime.attachLuaState(state)
  if dexPath and dexPath ~= "" then
    Runtime.startWithDex(activity, screenClass, token, dexPath, nil, argument)
  else
    Runtime.startWithDex(activity, screenClass, token, nil, nil, argument)
  end
  return true
end

-- 不挂 Lua，直接运行 Java 页面；用于验证单 Java 可用性。
function M.runStandalone(screenClass, dexPath, argument)
  bindClasses()
  Runtime.startWithDex(activity, screenClass, nil, dexPath, nil, argument)
end

-- 从 Lua 调动态 DEX 的 Java 静态方法，适合验证 Lua -> Java。
function M.callStatic(dexPath, className, methodName, argument)
  bindClasses()
  return Runtime.callStaticString(activity, dexPath, className, methodName, argument)
end

-- 编译示例工程并立即打开，返回编译结果；启动失败时 success 仍为 true。
function M.compileAndRun(project, screenClass)
  local result = M.compileAsset(project)
  if result.success then
    M.run(screenClass, result.dexPath)
  end
  return result
end

-- 后台编译并在成功后打开页面。
function M.compileAndRunAsync(project, screenClass, callback)
  M.compileAssetAsync(project, function(result)
    if result.success then
      M.run(screenClass, result.dexPath)
    end
    if callback then
      callback(result)
    end
  end)
end

return M
