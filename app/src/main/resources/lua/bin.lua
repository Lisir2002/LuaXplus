require "import"
import "java.util.zip.ZipOutputStream"
import "android.net.Uri"
import "java.io.File"
import "android.widget.Toast"
import "java.util.zip.CheckedInputStream"
import "java.io.FileInputStream"
import "android.content.Intent"
import "java.util.ArrayList"
import "java.io.FileOutputStream"
import "java.io.BufferedOutputStream"
import "java.util.zip.ZipInputStream"
import "java.io.BufferedInputStream"
import "java.util.zip.ZipEntry"
import "android.app.ProgressDialog"
import "java.util.zip.CheckedOutputStream"
import "java.util.zip.Adler32"
import "com.mini.luaxplus.ArscPackage"

local bin_dlg, error_dlg
local create_error_dlg2
local function update(s)
    bin_dlg.setMessage(s)
end

local function callback(s)
    LuaUtil.rmDir(File(activity.getLuaExtDir("bin/.temp")))
    bin_dlg.hide()
    bin_dlg.Message = ""
    s = tostring(s or "")
    if s == "" then
        s = "打包任务没有返回结果，请查看运行日志"
    end
    if not s:find("成功") then
        if not error_dlg then
            create_error_dlg2()
        end
        error_dlg.Message = s
        error_dlg.show()
    end
end

local function create_bin_dlg()
    if bin_dlg then
        return
    end
    bin_dlg = ProgressDialog(activity);
    bin_dlg.setTitle("正在打包");
    bin_dlg.setMax(100);
end

create_error_dlg2 = function()
    if error_dlg then
        return
    end
    error_dlg = AlertDialogBuilder(activity)
    error_dlg.Title = "出错"
    error_dlg.setPositiveButton("确定", nil)
end

local function readProjectProperties(root)
    local file = io.open(root .. "project.properties", "r")
    if not file then
        return nil
    end
    local properties = {}
    for raw in file:lines() do
        local line = raw:gsub("\r", "")
        if line:match("%S") and not line:match("^%s*#") then
            local key, value = line:match("^([^=]+)=(.*)$")
            if key then
                properties[key:match("^%s*(.-)%s*$")] = value:match("^%s*(.-)%s*$")
            end
        end
    end
    file:close()
    return properties
end

local function isJavaProjectProperties(properties)
    return properties ~= nil and tostring(properties.type or ""):lower() == "java"
end

local function binapk(luapath, apkpath)
    local function tointeger(value)
        local number = tonumber(value)
        if number == nil then
            return nil
        end
        return math.floor(number)
    end
    -- 放进函数内部，异步任务执行时不会依赖模块闭包
    local MANDATORY_PERMISSIONS = {
        "INTERNET",
        "WRITE_EXTERNAL_STORAGE",
        "READ_EXTERNAL_STORAGE",
        "MANAGE_EXTERNAL_STORAGE",
    }
    require "import"
    import "console"
    local function readProjectProperties(root, fileName)
        fileName = fileName or "project.properties"
        local file = io.open(root .. fileName, "r")
        if not file then
            return nil
        end
        local properties = {}
        for raw in file:lines() do
            local line = raw:gsub("\r", "")
            if line:match("%S") and not line:match("^%s*#") then
                local key, value = line:match("^([^=]+)=(.*)$")
                if key then
                    properties[key:match("^%s*(.-)%s*$")] = value:match("^%s*(.-)%s*$")
                end
            end
        end
        file:close()
        return properties
    end

    -- 异步任务会在新的 Lua 状态里执行，函数外层的局部变量和 Lua 表都不会保留，
    -- 所以这里从工程目录重新读取描述文件，只依赖字符串路径参数。
    local props = readProjectProperties(luapath)
    local javaProject = props ~= nil and tostring(props.type or ""):lower() == "java"
    -- 纯 Java 页面不挂载 LuaState，不需要 libluajava 等原生库；剔除后也能避开
    -- Android 15 设备对 4 KB 原生库页对齐的安装兼容检查。
    local pureJavaNoLua = javaProject and tostring(props.lua or "") == ""
    local pinfo
    if javaProject then
        pinfo = props
        if not pinfo.screen or pinfo.screen == "" then
            return "Java 工程缺少 screen 页面类"
        end
    else
        pinfo = {}
        local initOk, initErr = pcall(function()
            loadfile(luapath .. "init.lua", "bt", pinfo)()
        end)
        if not initOk then
            return "打包配置异常：" .. tostring(initErr)
        end
        local logProps = readProjectProperties(luapath, "log.properties")
        if logProps and logProps.inject_log ~= nil then
            pinfo.inject_log = logProps.inject_log
        end
    end

    -- 全局字段沿用现有打包脚本的清单替换逻辑，来源由工程描述统一提供。
    appname = tostring(pinfo.appname or pinfo.name or "app")
    appver = tostring(pinfo.appver or pinfo.version or "1.0")
    packagename = tostring(pinfo.packagename or pinfo["package"] or activity.getPackageName())
    path_pattern = pinfo.path_pattern

    -- 先只读预检：入口文件、Lua 语法、.aly 布局语法一次查完。
    -- Java 工程没有 Lua 入口，编译检查由下面的 Java 编译步骤负责。
    if not javaProject then
        local preflightOk, preflight = pcall(function()
            local module = require "packcheck"
            return module.check(luapath)
        end)
        if not preflightOk then
            return "打包前检查异常：" .. tostring(preflight)
        end
        if preflight and #preflight > 0 then
            return "打包前检查失败：\n" .. table.concat(preflight, "\n")
        end
    end

    compile "mao"
    compile "sign"
    import "java.util.zip.*"
    import "java.io.*"
    import "mao.res.*"
    import "apksigner.*"
    local b = byte[2 ^ 16]
    local function copy(input, output)
        LuaUtil.copyFile(input, output)
        input.close()
        --[[local l=input.read(b)
      while l>1 do
        output.write(b,0,l)
        l=input.read(b)
      end]]
    end

    local function copy2(input, output)
        LuaUtil.copyFile(input, output)
    end

    local temp = File(apkpath).getParentFile();
    if (not temp.exists()) then

        if (not temp.mkdirs()) then

            error("create file " .. temp.getName() .. " fail");
        end
    end


    local tmp = activity.getLuaPath("tmp.apk")
    local info = activity.getApplicationInfo()
    local ver = activity.getPackageManager().getPackageInfo(activity.getPackageName(), 0).versionName
    local code = activity.getPackageManager().getPackageInfo(activity.getPackageName(), 0).versionCode

    --local zip=ZipFile(info.publicSourceDir)
    local zipFile = File(info.publicSourceDir)
    local fis = FileInputStream(zipFile);
    --local checksum = CheckedInputStream(fis, Adler32());
    local zis = ZipInputStream(BufferedInputStream(fis));

    local fot = FileOutputStream(tmp)
    --local checksum2 = CheckedOutputStream(fot, Adler32());

    local out = ZipOutputStream(BufferedOutputStream(fot))
    local f = File(luapath)
    local errbuffer = {}
    local replace = {}
    local checked = {}
    local lualib = {}
    local md5s = {}
    local javaDexReady = false
    local libs = File(activity.ApplicationInfo.nativeLibraryDir).list()
    libs = luajava.astable(libs)
    for k, v in ipairs(libs) do
        --libs[k]="lib/armeabi/"..libs[k]
        replace[v] = true
    end

    local mdp = activity.Application.MdDir
    local function getmodule(dir)
        local mds = File(activity.Application.MdDir .. dir).listFiles()
        mds = luajava.astable(mds)
        for k, v in ipairs(mds) do
            if mds[k].isDirectory() then
                getmodule(dir .. mds[k].Name .. "/")
            else
                mds[k] = "lua" .. dir .. mds[k].Name
                replace[mds[k]] = true
            end
        end
    end

    getmodule("/")

    local function checklib(path)
        if checked[path] then
            return
        end
        local cp, lp
        checked[path] = true
        local f = io.open(path)
        local s = f:read("*a")
        f:close()
        for mod, sub in s:gmatch("require *%(? *\"([%w_]+)%.?([%w_]*)") do
            local m, n = mod, sub
            cp = string.format("lib%s.so", m)
            if n ~= "" then
                lp = string.format("lua/%s/%s.lua", m, n)
                m = m .. '/' .. n
            else
                lp = string.format("lua/%s.lua", m)
            end
            if replace[cp] then
                replace[cp] = false
            end
            if replace[lp] then
                checklib(mdp .. "/" .. m .. ".lua")
                replace[lp] = false
                lualib[lp] = mdp .. "/" .. m .. ".lua"
            end
        end
        for mod, sub in s:gmatch("import *%(? *\"([%w_]+)%.?([%w_]*)") do
            local m, n = mod, sub
            cp = string.format("lib%s.so", m)
            if n ~= "" then
                lp = string.format("lua/%s/%s.lua", m, n)
                m = m .. '/' .. n
            else
                lp = string.format("lua/%s.lua", m)
            end
            if replace[cp] then
                replace[cp] = false
            end
            if replace[lp] then
                checklib(mdp .. "/" .. m .. ".lua")
                replace[lp] = false
                lualib[lp] = mdp .. "/" .. m .. ".lua"
            end
        end
    end

    replace["libluajava.so"] = false
    -- Lua/混合成品需要原生崩溃守卫；纯 Java 成品在下面的循环里整体跳过 lib/
    replace["libcrashguard.so"] = false

    local function addDir(out, dir, f)
        local entry = ZipEntry("assets/" .. dir)
        out.putNextEntry(entry)
        local ls = f.listFiles()
        for n = 0, #ls - 1 do
            local name = ls[n].getName()
            if name==(".using") then
                checklib(luapath .. dir .. name)
            elseif name == ".build" then
                -- 编译中间产物由单独的 DEX 注入流程处理，不把整个构建目录带进成品
            elseif name:find("%.apk$") or name:find("%.luac$") or name:find("^%.") then
            elseif name:find("%.java$") then
                -- 成品运行已编译的 DEX，不携带 Java 源码
            elseif name:find("%.lua$") then
                checklib(luapath .. dir .. name)
                local path, err = console.build(luapath .. dir .. name)
                if path then
                    if replace["assets/" .. dir .. name] then
                        table.insert(errbuffer, dir .. name .. "/.aly")
                    end
                    local entry = ZipEntry("assets/" .. dir .. name)
                    out.putNextEntry(entry)

                    replace["assets/" .. dir .. name] = true
                    copy(FileInputStream(File(path)), out)
                    table.insert(md5s, LuaUtil.getFileMD5(path))
                    os.remove(path)
                else
                    table.insert(errbuffer, err)
                end
            elseif name:find("%.aly$") then
                local path, err = console.build(luapath .. dir .. name)
                if path then
                    name = name:gsub("aly$", "lua")
                    if replace["assets/" .. dir .. name] then
                        table.insert(errbuffer, dir .. name .. "/.aly")
                    end
                    local entry = ZipEntry("assets/" .. dir .. name)
                    out.putNextEntry(entry)

                    replace["assets/" .. dir .. name] = true
                    copy(FileInputStream(File(path)), out)
                    table.insert(md5s, LuaUtil.getFileMD5(path))
                    os.remove(path)
                else
                    table.insert(errbuffer, err)
                end
            elseif ls[n].isDirectory() then
                addDir(out, dir .. name .. "/", ls[n])
            else
                local entry = ZipEntry("assets/" .. dir .. name)
                out.putNextEntry(entry)
                replace["assets/" .. dir .. name] = true
                copy(FileInputStream(ls[n]), out)
                table.insert(md5s, LuaUtil.getFileMD5(ls[n]))
            end
        end
    end


    local function hasJavaFiles(dir)
        local list = dir.listFiles()
        if not list then
            return false
        end
        for _, child in ipairs(luajava.astable(list)) do
            if child.isDirectory() then
                if hasJavaFiles(child) then
                    return true
                end
            elseif child.isFile() and child.getName():match("%.java$") then
                return true
            end
        end
        return false
    end

    local javaNeeded = hasJavaFiles(f)
    if javaNeeded then
        this.update("正在编译 Java...")
        local sdk = 0
        pcall(function()
            sdk = tonumber(luajava.bindClass("android.os.Build").VERSION.SDK_INT) or 0
        end)
        if sdk < 26 then
            table.insert(errbuffer, "Java 编译需要 Android 8.0 及以上系统")
        else
            local ok, result = pcall(function()
                local compiler = luajava.bindClass("com.mini.luaxplus.java.JavaProjectCompiler")
                return compiler.compile(activity, luapath, luapath .. ".build/java")
            end)
            if not ok then
                table.insert(errbuffer, "Java 编译器不可用：" .. tostring(result))
            elseif not result.success then
                table.insert(errbuffer, "Java 编译失败：\n" .. tostring(result.message))
            else
                javaDexReady = true
            end
        end
    else
        this.update("正在检查工程...")
    end
    if f.isDirectory() then
        if not javaProject then
            require "permission"
            dofile(luapath .. "init.lua")
            if user_permission then
                for k, v in ipairs(user_permission) do
                    user_permission[v] = true
                end
            end
        end


        local ss, ee = pcall(addDir, out, "", f)
        if not ss then
            table.insert(errbuffer, ee)
        end
        -- 成品日志开关：写入一个独立配置，成品启动时据此决定是否启用崩溃报告。
        local injectLog = true
        if pinfo.inject_log ~= nil then
            local flag = tostring(pinfo.inject_log)
            injectLog = flag ~= "false" and flag ~= "0"
        end
        local logText = "enabled=" .. (injectLog and "true" or "false")
                .. "\npackage=" .. tostring(packagename or "") .. "\n"
        local logOk, logErr = pcall(function()
            local audit = luajava.bindClass("com.mini.luaxplus.PackAudit")
            audit.writeText(out, "assets/luaxplus/logging.properties", logText)
        end)
        if logOk then
            replace["assets/luaxplus/logging.properties"] = true
        else
            table.insert(errbuffer, "日志配置写入失败：" .. tostring(logErr))
        end
        -- 只有工程确实需要 Java 且编译成功时，才把 DEX 放进 assets/java。
        -- 成品启动时由 JavaDexLoader 读取，不再携带编译器或编译库。
        if javaDexReady then
            local javaDexDir = File(luapath .. ".build/java/dex")
            if javaDexDir.isDirectory() then
                local dexList = luajava.astable(javaDexDir.listFiles())
                for _, dex in ipairs(dexList) do
                    if dex.isFile() and dex.getName():match("%.dex$") then
                        local dexName = "assets/java/" .. dex.getName()
                        local dexEntry = ZipEntry(dexName)
                        out.putNextEntry(dexEntry)
                        replace[dexName] = true
                        copy(FileInputStream(dex), out)
                    end
                end
            end
        end
        --print(ee,dump(errbuffer),dump(replace))


        local wel = File(luapath .. "icon.png")
        if wel.exists() then
            local entry = ZipEntry("res/drawable/icon.png")
            out.putNextEntry(entry)
            replace["res/drawable/icon.png"] = true
            copy(FileInputStream(wel), out)
        end
        local wel = File(luapath .. "welcome.png")
        if wel.exists() then
            local entry = ZipEntry("res/drawable/welcome.png")
            out.putNextEntry(entry)
            replace["res/drawable/welcome.png"] = true
            copy(FileInputStream(wel), out)
        end
    else
        return "error"
    end

    --print(dump(lualib))
    for name, v in pairs(lualib) do
        local path, err = console.build(v)
        if path then
            local entry = ZipEntry(name)
            out.putNextEntry(entry)
            copy(FileInputStream(File(path)), out)
            table.insert(md5s, LuaUtil.getFileMD5(path))
            os.remove(path)
        else
            table.insert(errbuffer, err)
        end
    end

    function touint32(i)
        local code = string.format("%08x", i)
        local uint = {}
        for n in code:gmatch("..") do
            table.insert(uint, 1, string.char(tonumber(n, 16)))
        end
        return table.concat(uint)
    end

    this.update("正在打包...");
    -- 成品只运行已有 DEX，不需要编译器。先找出基础包里只含编译器类的 DEX，
    -- 打包时整块跳过；与运行时代码共用的 DEX 不能按文件名盲删。
    local compilerDexes = {}
    local auditOk, compilerList = pcall(function()
        local audit = luajava.bindClass("com.mini.luaxplus.PackAudit")
        return audit.compilerOnlyDex(zipFile.getAbsolutePath())
    end)
    if auditOk and compilerList then
        for _, dexName in ipairs(luajava.astable(compilerList)) do
            compilerDexes[dexName] = true
        end
    else
        -- 审计失败时宁可不裁剪，也不能误删含运行时父类的 DEX。
        compilerDexes = {}
    end
    local entry = zis.getNextEntry();
    while entry do
        local name = entry.getName()
        local lib = name:match("([^/]+%.so)$")
        if replace[name] then
        elseif lib and replace[lib] then
        elseif pureJavaNoLua and name:find("^lib/") then
        elseif compilerDexes[name] then
        elseif name:find("^assets/") and (not name:find("^assets/lua/")) and (not name:find("^assets/luaxplus/")) then
        elseif name:find("^lua/") then
        elseif name:find("META%-INF") then
        elseif not name:find("%a") then
        else
            local entry = ZipEntry(name)
            if name == "resources.arsc" then
                ArscPackage.writeStored(out, name, zis, packagename)
            else
            out.putNextEntry(entry)
            if entry.getName() == "AndroidManifest.xml" then
                if path_pattern and #path_pattern > 1 then
                    path_pattern = ".*\\\\." .. path_pattern:match("%w+$")
                end
                local list = ArrayList()
                local xml = AXmlDecoder.read(list, zis)
                local req = {
                    [activity.getPackageName()] = packagename,
                    [activity.getPackageName()..".androidx-startup"] = packagename..".androidx-startup",
                    [activity.getPackageName()..".crashbootstrap"] = packagename..".crashbootstrap",
                    [activity.getPackageName()..".DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION"] = packagename..".DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION",
                    [info.nonLocalizedLabel] = appname,
                    [ver] = appver,
                    [".*\\\\.lua"] = "",
                    [".*\\\\.luac"] = "",
                }
                if path_pattern==nil or path_pattern=="" then
                    req[".*\\\\.alp"] = ""
                    req["application/alp"] = "application/1234567890"
                  else
                    path_pattern=path_pattern:match("%w+$") or path_pattern
                    req[".*\\\\.alp"] = ".*\\\\."..path_pattern
                    req["application/alp"] = "application/"..path_pattern
                end
                -- 默认继承模板的完整权限清单；项目勾选了权限注入时按勾选裁剪，
                -- 并始终保留日志与基础功能所需的权限
                local keep = nil
                if pinfo.strict_permissions then
                    keep = {}
                    for _, item in ipairs(pinfo.user_permission or {}) do
                        keep[(item:gsub("android%.permission%.", ""))] = true
                    end
                    for _, item in ipairs(MANDATORY_PERMISSIONS) do
                        keep[item] = true
                    end
                end
                for n = 0, list.size() - 1 do
                    local v = list.get(n)
                    if req[v] then
                        list.set(n, req[v])
                    elseif keep then
                        local p = v:match("%.permission%.([%w_]+)$")
                        if p and (not keep[p]) then
                            list.set(n, "android.permission.UNKNOWN")
                        end
                    end
                end
                local pt = activity.getLuaPath(".tmp")
                local fo = FileOutputStream(pt)
                xml.write(list, fo)
                fo.close()
                local fi = FileInputStream(pt)
                copy(fi, out)
                os.remove(pt)
            elseif not entry.isDirectory() then
                copy2(zis, out)
            end
            end
        end
        entry = zis.getNextEntry()
    end
    out.setComment(table.concat(md5s))
    --print(table.concat(md5s,"/n"))
    zis.close();
    out.closeEntry()
    out.close()

    -- 成品必须带上主程序日志与崩溃入口；缺失时直接阻止签名，避免生成无声崩溃的包。
    if #errbuffer == 0 then
        local auditOk, missing = pcall(function()
            local audit = luajava.bindClass("com.mini.luaxplus.PackAudit")
            return audit.missingLogClasses(tmp)
        end)
        if not auditOk then
            table.insert(errbuffer, "日志系统注入审计失败：" .. tostring(missing))
        elseif missing then
            local missingList = luajava.astable(missing)
            if #missingList > 0 then
                table.insert(errbuffer, "日志系统注入不完整：" .. table.concat(missingList, ", "))
            end
        end
    end

    if #errbuffer == 0 then
        local guardOk, guardMissing = pcall(function()
            local audit = luajava.bindClass("com.mini.luaxplus.PackAudit")
            return audit.missingNativeCrashGuard(tmp)
        end)
        if not guardOk then
            table.insert(errbuffer, "原生崩溃守卫审计失败：" .. tostring(guardMissing))
        elseif guardMissing then
            local guardList = luajava.astable(guardMissing)
            if #guardList > 0 then
                table.insert(errbuffer, "成品含原生库但缺少 libcrashguard.so：" ..
                        table.concat(guardList, ", "))
            end
        end
    end

    if #errbuffer == 0 then
        this.update("正在签名...");
        os.remove(apkpath)
        local signed, signErr = pcall(function()
            luajava.bindClass("com.mini.luaxplus.PackSigner").sign(activity, tmp, apkpath)
        end)
        if not signed then
            pcall(function()
                luajava.bindClass("com.mini.luaxplus.LogCore")
                    .luaError("打包签名失败 " .. tostring(apkpath), tostring(signErr))
            end)
            return "打包签名失败：" .. tostring(signErr)
        end
        os.remove(tmp)
        local installOk, installErr = pcall(function()
            activity.installApk(apkpath)
        end)
        if not installOk then
            pcall(function()
                luajava.bindClass("com.mini.luaxplus.LogCore")
                    .luaError("安装器启动失败 " .. tostring(apkpath), tostring(installErr))
            end)
            return "打包成功:" .. apkpath .. "\n安装器启动失败，请到 bin 目录手动安装"
        end
        --[[import "android.net.*"
        import "android.content.*"
        i = Intent(Intent.ACTION_VIEW);
        i.setDataAndType(activity.getUriForFile(File(apkpath)), "application/vnd.android.package-archive");
        i.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        this.update("正在打开...");
        activity.startActivityForResult(i, 0);]]
        return "打包成功:" .. apkpath
    else
        os.remove(tmp)
        local message = table.concat(errbuffer, "\n")
        pcall(function()
            luajava.bindClass("com.mini.luaxplus.LogCore")
                .luaError("打包失败 " .. tostring(apkpath), message)
        end)
        this.update("打包出错:\n " .. message);
        return "打包出错:\n " .. message
    end
end

--luabindir=activity.getLuaExtDir("bin")
--print(activity.getLuaExtPath("bin","a"))
local function bin(path)
    local descriptor = readProjectProperties(path)
    local p
    if isJavaProjectProperties(descriptor) then
        p = {
            javaProject = true,
            type = "java",
            appname = descriptor.name or "Java 工程",
            appver = descriptor.version or "1.0",
            appcode = descriptor.code,
            appsdk = descriptor.sdk,
            packagename = descriptor["package"],
            path_pattern = descriptor.path_pattern,
            screen = descriptor.screen,
            argument = descriptor.argument,
            lua = descriptor.lua,
            official = descriptor.official,
        }
    else
        p = {}
        local loaded, chunk = pcall(loadfile, path .. "init.lua", "bt", p)
        if not loaded or type(chunk) ~= "function" then
            Toast.makeText(activity, "工程配置文件错误." .. tostring(chunk), Toast.LENGTH_SHORT).show()
            return
        end
        local ran, runError = pcall(chunk)
        if not ran then
            Toast.makeText(activity, "工程配置文件执行失败." .. tostring(runError), Toast.LENGTH_SHORT).show()
            return
        end
    end
    create_bin_dlg()
    bin_dlg.show()
    local appName = tostring(p.appname or "app")
    local appVer = tostring(p.appver or "1.0")
    activity.newTask(binapk, update, callback).execute { path, activity.getLuaExtPath("bin", appName .. "_" .. appVer .. ".apk") }
end

--bin(activity.getLuaExtDir("project/demo").."/")
return bin