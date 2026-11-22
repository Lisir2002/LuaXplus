-- 打包预检的纯文件系统测试。用 fake File 模拟 Android 的 java.io.File。

local function quote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function write(path, content)
  local handle = assert(io.open(path, "wb"))
  handle:write(content)
  handle:close()
end

local root = "/tmp/luax-packcheck"
os.execute("rm -rf " .. quote(root))
os.execute("mkdir -p " .. quote(root .. "/sub"))
write(root .. "/main.lua", "return true\n")
write(root .. "/init.lua", "appname = 'demo'\n")
write(root .. "/ok.lua", "return 1\n")
write(root .. "/bad.lua", "local x =\n")
write(root .. "/ok.aly", "{ layout = 'vertical' }\n")
write(root .. "/bad.aly", "{ layout = \n")
write(root .. "/sub/ok.lua", "return { ok = true }\n")
write(root .. "/.hidden.lua", "local broken =\n")
write(root .. "/icon.apk", "not a lua file")

local function fakeFile(path)
  local file = {}
  file.getPath = function() return path end
  file.getName = function() return path:match("[^/]+$") or path end
  file.exists = function() return os.execute("test -e " .. quote(path)) end
  file.isDirectory = function() return os.execute("test -d " .. quote(path)) end
  file.listFiles = function()
    if not file.isDirectory() then
      return nil
    end
    local result = {}
    local pipe = io.popen("find " .. quote(path) .. " -mindepth 1 -maxdepth 1 -print")
    if pipe then
      for child in pipe:lines() do
        result[#result + 1] = fakeFile(child)
      end
      pipe:close()
    end
    return result
  end
  return file
end

luajava = {
  bindClass = function(name)
    assert(name == "java.io.File", "packcheck 只应加载 java.io.File，实际：" .. tostring(name))
    return fakeFile
  end,
}

local packcheck = assert(loadfile("app/src/main/resources/lua/packcheck.lua"))()
local errors = packcheck.check(root)
assert(errors and #errors == 2, "应发现 2 个语法错误，实际：" .. tostring(errors and #errors))
local joined = table.concat(errors, "\n")
assert(joined:find("bad.lua", 1, true), "未报告 bad.lua：" .. joined)
assert(joined:find("bad.aly", 1, true), "未报告 bad.aly：" .. joined)
assert(not joined:find("ok.lua", 1, true), "误报 ok.lua：" .. joined)
assert(not joined:find("ok.aly", 1, true), "误报 ok.aly：" .. joined)
assert(not joined:find("sub/ok.lua", 1, true), "误报子目录文件：" .. joined)

os.execute("mkdir -p " .. quote("/tmp/luax-packcheck-empty"))
local emptyErrors = packcheck.check("/tmp/luax-packcheck-empty")
assert(emptyErrors and #emptyErrors == 1 and emptyErrors[1]:find("main.lua", 1, true),
  "缺少入口文件时没有报错")

local missingErrors = packcheck.check("/tmp/luax-packcheck-not-here")
assert(missingErrors and #missingErrors == 1 and missingErrors[1]:find("工程目录不存在", 1, true),
  "不存在的工程目录没有报错")

os.execute("rm -rf " .. quote(root) .. " " .. quote("/tmp/luax-packcheck-empty"))
print("[lua-smoke] 打包预检通过")
