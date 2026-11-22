require "import"
import "android.app.*"
import "android.os.*"
import "android.widget.*"
import "android.view.*"
import "android.graphics.drawable.*"
import "android.graphics.Typeface"
import "java.io.File"
import "com.google.android.material.dialog.MaterialAlertDialogBuilder"
import "loadbitmap"
import "autotheme"
import "androidx.drawerlayout.widget.DrawerLayout"
import "com.androlua.LuaFileObserver"

-- 首页：应用（项目）列表
-- 数据来源：外部目录 project 下的工程文件夹，每个文件夹带 init.lua 描述信息

activity.setTheme(autotheme())
activity.setTitle("应用")

-- 页面自带标题区，隐藏系统标题栏
pcall(function()
  local actionBar = activity.getActionBar()
  if actionBar then
    actionBar.hide()
  end
end)
pcall(function()
  local supportBar = activity.getSupportActionBar()
  if supportBar then
    supportBar.hide()
  end
end)

local PAPER = 0xfff7f1e6
local CARD = 0xFFFFFDF8
local INK = 0xff1c2b3a
local MUTED = 0xff5f6f7c
local ACCENT = 0xff0f9e97
local LINE = 0xffe6dbc8

local projectRoot = activity.getLuaExtDir("project")
local examplesRoot = activity.getLuaExtDir("examples")

local function dp(n)
  return math.floor(n * activity.getResources().getDisplayMetrics().density + 0.5)
end

local function rounded(fill, stroke, radius)
  local drawable = GradientDrawable()
  drawable.setShape(GradientDrawable.RECTANGLE)
  drawable.setColor(fill)
  drawable.setCornerRadius(dp(radius))
  if stroke then
    drawable.setStroke(dp(1), stroke)
  end
  return drawable
end

-- 统一的工程信息落盘，避免局部修改把其它字段冲掉
local function writeInfo(info)
  local function str(value)
    return string.format("%q", tostring(value or ""))
  end
  if info.debugmode == nil then
    info.debugmode = true
  end
  local lines = {
    "appname=" .. str(info.appname or "未命名"),
    "appver=" .. str(info.appver or "1.0"),
    "appcode=" .. str(info.appcode or "1"),
    "appsdk=" .. str(info.appsdk or "15"),
    "path_pattern=" .. str(info.path_pattern or ""),
    "packagename=" .. str(info.packagename or "com.mini.app"),
    "theme=" .. str(info.theme or "Theme_Material_Light"),
    "app_key=" .. str(info.app_key or ""),
    "app_channel=" .. str(info.app_channel or ""),
    "developer=" .. str(info.developer or ""),
    "description=" .. str(info.description or ""),
    "debugmode=" .. (info.debugmode and "true" or "false"),
  }
  local permissions = {}
  for _, item in ipairs(info.user_permission or {}) do
    table.insert(permissions, string.format("%q", item))
  end
  table.insert(lines, "user_permission={" .. table.concat(permissions, ",\n  ") .. "}")
  if info.official then
    table.insert(lines, "official=true")
  end
  if info.strict_permissions then
    table.insert(lines, "strict_permissions=true")
  end
  local file = io.open(info.path .. "/init.lua", "w")
  if not file then
    return
  end
  file:write(table.concat(lines, "\n") .. "\n")
  file:close()
end

local function readInfo(dir)
  local info = {}
  local ok = pcall(function()
    local chunk = loadfile(dir .. "/init.lua", "bt", info)
    if chunk then
      chunk()
    end
  end)
  if not ok then
    return nil
  end
  if not info.appname then
    return nil
  end
  info.path = dir
  return info
end

local function dirSize(dir)
  local total = 0
  local function walk(path)
    local file = File(path)
    local list = file.listFiles()
    if not list then
      return
    end
    for i = 0, #list - 1 do
      local item = list[i]
      if item.isDirectory() then
        walk(item.getAbsolutePath())
      else
        total = total + item.length()
      end
    end
  end
  walk(dir)
  return total
end

local function humanSize(bytes)
  if bytes < 1024 then
    return bytes .. " B"
  elseif bytes < 1024 * 1024 then
    return string.format("%.1f KB", bytes / 1024)
  end
  return string.format("%.1f MB", bytes / 1024 / 1024)
end

local drawerLayout = DrawerLayout(activity)
drawerLayout.setScrimColor(0x99000000)
local sidePanel

local root = LinearLayout(activity)
root.setOrientation(LinearLayout.VERTICAL)
root.setBackgroundColor(PAPER)
root.setFitsSystemWindows(true)

-- 顶部标题区
local header = LinearLayout(activity)
header.setOrientation(LinearLayout.HORIZONTAL)
header.setGravity(Gravity.CENTER_VERTICAL)
header.setPadding(dp(10), dp(16), dp(14), dp(6))

local menuBtn = TextView(activity)
menuBtn.setText("≡")
menuBtn.setTextSize(22)
menuBtn.setTextColor(INK)
menuBtn.setGravity(Gravity.CENTER)
menuBtn.setPadding(0, 0, 0, 0)
header.addView(menuBtn, LinearLayout.LayoutParams(dp(34), -2))

local title = TextView(activity)
title.setText("应用")
title.setTextSize(23)
title.setTypeface(Typeface.DEFAULT_BOLD)
title.setTextColor(INK)
header.addView(title, LinearLayout.LayoutParams(0, -2, 1))

local editorBtn = TextView(activity)
editorBtn.setText("编辑器")
editorBtn.setTextSize(13)
editorBtn.setTextColor(INK)
editorBtn.setGravity(Gravity.CENTER)
editorBtn.setPadding(dp(12), dp(7), dp(12), dp(7))
editorBtn.setBackground(rounded(CARD, LINE, 10))
header.addView(editorBtn)

local newBtn = TextView(activity)
newBtn.setText("新建")
newBtn.setTextSize(13)
newBtn.setTextColor(0xff0b6f6a)
newBtn.setGravity(Gravity.CENTER)
newBtn.setPadding(dp(13), dp(7), dp(13), dp(7))
newBtn.setBackground(rounded(0xffdff3f0, 0xffbfe6e1, 10))
local newParams = LinearLayout.LayoutParams(-2, -2)
newParams.leftMargin = dp(8)
header.addView(newBtn, newParams)

root.addView(header, LinearLayout.LayoutParams(-1, -2))

-- 搜索框
local searchWrap = LinearLayout(activity)
searchWrap.setPadding(dp(18), dp(4), dp(18), dp(8))
local search = EditText(activity)
search.setHint("搜索应用名称或包名")
search.setTextSize(14)
search.setTextColor(INK)
search.setSingleLine(true)
search.setBackground(rounded(CARD, LINE, 12))
search.setPadding(dp(14), dp(9), dp(14), dp(9))
searchWrap.addView(search, LinearLayout.LayoutParams(-1, -2))
root.addView(searchWrap, LinearLayout.LayoutParams(-1, -2))

-- 统计行
local summary = TextView(activity)
summary.setTextSize(12)
summary.setTextColor(MUTED)
summary.setPadding(dp(20), 0, dp(18), dp(6))
root.addView(summary, LinearLayout.LayoutParams(-1, -2))

-- 列表
local scroll = ScrollView(activity)
scroll.setFillViewport(true)
local list = LinearLayout(activity)
list.setOrientation(LinearLayout.VERTICAL)
list.setPadding(dp(16), dp(4), dp(16), dp(20))
scroll.addView(list, LinearLayout.LayoutParams(-1, -2))
root.addView(scroll, LinearLayout.LayoutParams(-1, 0, 1))

drawerLayout.addView(root, DrawerLayout.LayoutParams(-1, -1))
activity.setContentView(drawerLayout)

local projects = {}

local function openProject(info)
  activity.newActivity("projectpage", {info.path})
end

local function toast(text)
  Toast.makeText(activity, text, Toast.LENGTH_SHORT).show()
end

local function removeProject(info)
  MaterialAlertDialogBuilder(activity)
    .setTitle("删除应用")
    .setMessage("确定删除「" .. info.appname .. "」？文件夹会一并移除，无法恢复。")
    .setNegativeButton("取消", nil)
    .setPositiveButton("删除", function()
      local function drop(path)
        local file = File(path)
        if file.isDirectory() then
          local children = file.listFiles()
          if children then
            for i = 0, #children - 1 do
              drop(children[i].getAbsolutePath())
            end
          end
        end
        file.delete()
      end
      drop(info.path)
      toast("已删除「" .. info.appname .. "」，外部目录已同步移除")
      refresh()
    end)
    .show()
end

local function showProjectMenu(info)
  local options = {"重命名", "删除", "打开所在目录"}
  MaterialAlertDialogBuilder(activity)
    .setTitle(info.appname)
    .setItems(options, function(dialog, which)
      if which == 0 then
        local input = EditText(activity)
        input.setText(info.appname)
        MaterialAlertDialogBuilder(activity)
          .setTitle("重命名应用")
          .setView(input)
          .setNegativeButton("取消", nil)
          .setPositiveButton("保存", function()
            local name = input.getText().toString()
            if name == "" then
              return
            end
            local info2 = readInfo(info.path)
            info2.appname = name
            writeInfo(info2)
            toast("已重命名")
            refresh()
          end)
          .show()
      elseif which == 1 then
        removeProject(info)
      else
        toast("目录：" .. info.path)
      end
    end)
    .show()
end

local function buildCard(info)
  local card = LinearLayout(activity)
  card.setOrientation(LinearLayout.HORIZONTAL)
  card.setGravity(Gravity.CENTER_VERTICAL)
  card.setPadding(dp(14), dp(13), dp(14), dp(13))
  card.setBackground(rounded(CARD, LINE, 16))

  local icon = ImageView(activity)
  local iconFile = File(info.path .. "/icon.png")
  if iconFile.exists() then
    icon.setImageBitmap(loadbitmap(iconFile.getAbsolutePath()))
  else
    icon.setImageResource(R.drawable.icon)
  end
  icon.setScaleType(ImageView.ScaleType.CENTER_CROP)
  icon.setBackground(rounded(0xfff2ece0, nil, 12))
  card.addView(icon, LinearLayout.LayoutParams(dp(50), dp(50)))

  local texts = LinearLayout(activity)
  texts.setOrientation(LinearLayout.VERTICAL)
  local params = LinearLayout.LayoutParams(0, -2, 1)
  params.leftMargin = dp(12)
  card.addView(texts, params)

  local name = TextView(activity)
  name.setText(info.appname .. "  v" .. (info.appver or "1.0"))
  name.setTextSize(16)
  name.setTypeface(Typeface.DEFAULT_BOLD)
  name.setTextColor(INK)
  texts.addView(name)

  local sub = TextView(activity)
  sub.setText((info.packagename or "未设置包名") .. " · " .. humanSize(dirSize(info.path)))
  sub.setTextSize(12)
  sub.setTextColor(MUTED)
  sub.setPadding(0, dp(3), 0, 0)
  texts.addView(sub)

  local desc = TextView(activity)
  desc.setText((info.description and info.description ~= "") and info.description or "未填写简介")
  desc.setTextSize(12.5)
  desc.setTextColor(0xff7d8b96)
  desc.setMaxLines(1)
  desc.setPadding(0, dp(4), 0, 0)
  texts.addView(desc)

  local arrow = TextView(activity)
  arrow.setText("›")
  arrow.setTextSize(18)
  arrow.setTextColor(0xff9fb0ba)
  card.addView(arrow)

  card.setOnClickListener(View.OnClickListener{
    onClick = function()
      openProject(info)
    end
  })
  card.setOnLongClickListener(View.OnLongClickListener{
    onLongClick = function()
      showProjectMenu(info)
      return true
    end
  })

  local wrapper = LinearLayout(activity)
  wrapper.setPadding(0, 0, 0, dp(10))
  wrapper.addView(card, LinearLayout.LayoutParams(-1, -2))
  return wrapper
end

local function buildEmpty()
  local box = LinearLayout(activity)
  box.setOrientation(LinearLayout.VERTICAL)
  box.setGravity(Gravity.CENTER)
  box.setPadding(dp(24), dp(60), dp(24), dp(40))

  local icon = ImageView(activity)
  icon.setImageResource(R.drawable.icon)
  icon.setAlpha(0.5)
  box.addView(icon, LinearLayout.LayoutParams(dp(64), dp(64)))

  local text = TextView(activity)
  text.setText("还没有应用")
  text.setTextSize(16)
  text.setTextColor(INK)
  text.setGravity(Gravity.CENTER)
  text.setPadding(0, dp(14), 0, dp(4))
  box.addView(text)

  local hint = TextView(activity)
  hint.setText("点右上角「新建」创建一个应用，脚本会写在 LuaXPlus/project 目录里")
  hint.setTextSize(12.5)
  hint.setTextColor(MUTED)
  hint.setGravity(Gravity.CENTER)
  box.addView(hint)
  return box
end

function refresh(keyword)
  list.removeAllViews()
  projects = {}
  local dirs = File(projectRoot).listFiles()
  if dirs then
    for i = 0, #dirs - 1 do
      local path = dirs[i].getAbsolutePath()
      local inExamples = examplesRoot ~= nil and examplesRoot ~= ""
        and (path == examplesRoot or path:find(examplesRoot .. "/", 1, true) == 1)
      if dirs[i].isDirectory() and not inExamples then
        local info = readInfo(path)
        if info then
          info.mtime = dirs[i].lastModified()
          table.insert(projects, info)
        end
      end
    end
  end
  table.sort(projects, function(a, b)
    return (a.mtime or 0) > (b.mtime or 0)
  end)

  local shown = 0
  local word = keyword and keyword:lower() or ""
  for i = 1, #projects do
    local info = projects[i]
    local text = ((info.appname or "") .. " " .. (info.packagename or "")):lower()
    if word == "" or text:find(word, 1, true) then
      list.addView(buildCard(info))
      shown = shown + 1
    end
  end

  if #projects == 0 then
    list.addView(buildEmpty())
    summary.setText("共 0 个应用")
  else
    summary.setText("共 " .. #projects .. " 个应用" .. (shown ~= #projects and ("，匹配 " .. shown .. " 个") or ""))
  end
end

search.addTextChangedListener{
  onTextChanged = function(c)
    refresh(tostring(c))
  end
}

local function createProject(name, pkg)
  local safe = name:gsub("[/\\%s]", "_")
  local dir = projectRoot .. "/" .. safe
  File(dir).mkdirs()
  writeInfo{
    path = dir,
    appname = name,
    appver = "1.0",
    packagename = pkg,
    developer = "",
    description = "",
    user_permission = { "INTERNET", "WRITE_EXTERNAL_STORAGE" },
  }

  local entry = io.open(dir .. "/main.lua", "w")
  entry:write('require "import"\n')
  entry:write('import "android.widget.*"\n')
  entry:write('import "android.view.*"\n')
  entry:write('import "autotheme"\n\n')
  entry:write('activity.setTheme(autotheme())\n')
  entry:write('activity.setTitle(' .. string.format("%q", name) .. ')\n\n')
  entry:write('local layout = LinearLayout(activity)\n')
  entry:write('layout.setOrientation(LinearLayout.VERTICAL)\n')
  entry:write('layout.setGravity(Gravity.CENTER)\n\n')
  entry:write('local text = TextView(activity)\n')
  entry:write('text.setText("Hello, ' .. name .. '")\n')
  entry:write('text.setTextSize(20)\n')
  entry:write('layout.addView(text)\n\n')
  entry:write('activity.setContentView(layout)\n')
  entry:close()
end

newBtn.setOnClickListener(View.OnClickListener{
  onClick = function()
    local box = LinearLayout(activity)
    box.setOrientation(LinearLayout.VERTICAL)
    box.setPadding(dp(20), dp(8), dp(20), 0)

    local nameInput = EditText(activity)
    nameInput.setHint("应用名称，例如 记账本")
    nameInput.setSingleLine(true)
    box.addView(nameInput, LinearLayout.LayoutParams(-1, -2))

    local pkgInput = EditText(activity)
    pkgInput.setHint("包名，例如 com.mini.notes")
    pkgInput.setSingleLine(true)
    pkgInput.setText("com.mini.app")
    local pkgParams = LinearLayout.LayoutParams(-1, -2)
    pkgParams.topMargin = dp(10)
    box.addView(pkgInput, pkgParams)

    MaterialAlertDialogBuilder(activity)
      .setTitle("新建应用")
      .setView(box)
      .setNegativeButton("取消", nil)
      .setPositiveButton("创建", function()
        local name = nameInput.getText().toString()
        local pkg = pkgInput.getText().toString()
        if name == "" then
          toast("请填写应用名称")
          return
        end
        if not pkg:find("%.") then
          pkg = "com.mini." .. pkg
        end
        createProject(name, pkg)
        toast("已创建「" .. name .. "」")
        refresh()
      end)
      .show()
  end
})

local function collectScripts(directory, result, depth)
  if depth > 4 then
    return
  end
  local children = directory.listFiles()
  if not children then
    return
  end
  for index = 0, #children - 1 do
    local item = children[index]
    if item.isDirectory() then
      collectScripts(item, result, depth + 1)
    else
      local name = item.getName()
      if name:sub(-4) == ".lua" then
        local path = item.getAbsolutePath()
        local relative = path:sub(#projectRoot + 2)
        table.insert(result, {
          path = path,
          label = relative,
          time = item.lastModified()
        })
      end
    end
  end
end

local function showEditorPicker()
  local list = {}
  collectScripts(File(projectRoot), list, 0)
  if #list == 0 then
    toast("还没有脚本文件，先新建一个应用")
    return
  end
  table.sort(list, function(a, b)
    return a.time > b.time
  end)
  local labels = {}
  local limit = math.min(#list, 30)
  for index = 1, limit do
    table.insert(labels, list[index].label)
  end
  MaterialAlertDialogBuilder(activity)
    .setTitle("选择要编辑的文件")
    .setItems(labels, function(_, which)
      local item = list[which + 1]
      if item then
        pcall(function()
          activity.newActivity("editor", {item.path})
        end)
      end
    end)
    .setNegativeButton("取消", nil)
    .show()
end

editorBtn.setOnClickListener(View.OnClickListener{
  onClick = function()
    showEditorPicker()
  end
})

-- ===== 侧边栏 =====
local appVersion = ""
pcall(function()
  local info = activity.getPackageManager().getPackageInfo(activity.getPackageName(), 0)
  appVersion = tostring(info.versionName)
end)

local function showAbout()
  local ok, err = pcall(function()
    activity.newActivity("about")
  end)
  if not ok then
    toast("关于页启动失败：" .. tostring(err))
  end
end

local function showSettings()
  local ok, err = pcall(function()
    activity.newActivity("settings")
  end)
  if not ok then
    toast("设置页启动失败：" .. tostring(err))
  end
end

sidePanel = LinearLayout(activity)
sidePanel.setOrientation(LinearLayout.VERTICAL)
sidePanel.setBackgroundColor(CARD)
sidePanel.setPadding(dp(16), dp(16), dp(16), dp(18))

local sideHeader = LinearLayout(activity)
sideHeader.setOrientation(LinearLayout.HORIZONTAL)
sideHeader.setGravity(Gravity.CENTER_VERTICAL)
sidePanel.addView(sideHeader, LinearLayout.LayoutParams(-1, -2))

local brandBox = LinearLayout(activity)
brandBox.setOrientation(LinearLayout.VERTICAL)
sideHeader.addView(brandBox, LinearLayout.LayoutParams(0, -2, 1))

local brand = TextView(activity)
brand.setText("Mini-LuaXPLUS")
brand.setTextSize(16)
brand.setTypeface(Typeface.DEFAULT_BOLD)
brand.setTextColor(INK)
brandBox.addView(brand)

local brandHint = TextView(activity)
brandHint.setText("Lua 移动开发工作台")
brandHint.setTextSize(11)
brandHint.setTextColor(MUTED)
brandBox.addView(brandHint)

local closeBtn = TextView(activity)
closeBtn.setText("✕")
closeBtn.setTextSize(16)
closeBtn.setTextColor(MUTED)
closeBtn.setGravity(Gravity.CENTER)
closeBtn.setPadding(dp(8), dp(4), dp(8), dp(4))
sideHeader.addView(closeBtn, LinearLayout.LayoutParams(dp(32), -2))

local divider = View(activity)
divider.setBackgroundColor(LINE)
local dividerParams = LinearLayout.LayoutParams(-1, dp(1))
dividerParams.topMargin = dp(14)
dividerParams.bottomMargin = dp(8)
sidePanel.addView(divider, dividerParams)

local sectionLabel = TextView(activity)
sectionLabel.setText("菜单")
sectionLabel.setTextSize(10.5)
sectionLabel.setTextColor(MUTED)
sectionLabel.setPadding(dp(12), dp(4), 0, dp(2))
sidePanel.addView(sectionLabel)

local function sideEntry(badgeText, badgeColor, badgeBg, titleText, hintText, handler)
  local row = LinearLayout(activity)
  row.setOrientation(LinearLayout.HORIZONTAL)
  row.setGravity(Gravity.CENTER_VERTICAL)
  row.setPadding(dp(10), dp(10), dp(12), dp(10))
  row.setBackground(rounded(0xFFF3ECDE, nil, 12))

  local badge = TextView(activity)
  badge.setText(badgeText)
  badge.setTextSize(12)
  badge.setGravity(Gravity.CENTER)
  badge.setTextColor(badgeColor)
  badge.setBackground(rounded(badgeBg, nil, 9))
  row.addView(badge, LinearLayout.LayoutParams(dp(30), dp(30)))

  local textBox = LinearLayout(activity)
  textBox.setOrientation(LinearLayout.VERTICAL)
  local textParams = LinearLayout.LayoutParams(0, -2, 1)
  textParams.leftMargin = dp(11)
  row.addView(textBox, textParams)

  local entryTitle = TextView(activity)
  entryTitle.setText(titleText)
  entryTitle.setTextSize(14.5)
  entryTitle.setTextColor(INK)
  textBox.addView(entryTitle)

  local entryHint = TextView(activity)
  entryHint.setText(hintText)
  entryHint.setTextSize(11)
  entryHint.setTextColor(MUTED)
  entryHint.setPadding(0, dp(3), 0, 0)
  textBox.addView(entryHint)

  local arrow = TextView(activity)
  arrow.setText("›")
  arrow.setTextSize(16)
  arrow.setTextColor(MUTED)
  row.addView(arrow)

  local rowParams = LinearLayout.LayoutParams(-1, -2)
  rowParams.topMargin = dp(6)
  sidePanel.addView(row, rowParams)

  row.setOnClickListener(View.OnClickListener{
    onClick = function()
      drawerLayout.closeDrawer(sidePanel)
      handler()
    end
  })
  return row
end

sideEntry("例", 0xff0b6f6a, 0xffdff3f0, "官方示例", "内置完整组件示例，可编辑运行", function()
  local ok, err = pcall(function()
    activity.newActivity("examples")
  end)
  if not ok then
    Toast.makeText(activity, "示例页启动失败：" .. tostring(err), Toast.LENGTH_SHORT).show()
  end
end)
sideEntry("册", 0xff0b6f6a, 0xffdff3f0, "使用手册", "从快速开始查到打包排错", function()
  local ok, err = pcall(function()
    activity.newActivity("luadoc")
  end)
  if not ok then
    Toast.makeText(activity, "手册启动失败：" .. tostring(err), Toast.LENGTH_SHORT).show()
  end
end)
sideEntry("J", 0xff1f5f8b, 0xffe3f0fa, "Java 浏览器", "浏览类、方法、字段与事件说明", function()
  local ok, err = pcall(function()
    activity.newActivity("javaapi/main")
  end)
  if not ok then
    Toast.makeText(activity, "Java 浏览器启动失败：" .. tostring(err), Toast.LENGTH_SHORT).show()
  end
end)
sideEntry("关", 0xff0b6f6a, 0xffdff3f0, "关于", "版本信息与开发说明", showAbout)
sideEntry("设", 0xff7a6a56, 0xfff0e4d4, "设置", "偏好与行为配置", showSettings)

local sideFooter = TextView(activity)
sideFooter.setText(appVersion ~= "" and appVersion or "1.0.0-rc9")
sideFooter.setTextSize(10.5)
sideFooter.setTextColor(MUTED)
sideFooter.setPadding(dp(12), dp(20), 0, 0)
sidePanel.addView(sideFooter)

pcall(function()
  sidePanel.setElevation(dp(14))
end)

local sideParams = DrawerLayout.LayoutParams(dp(284), -1)
sideParams.gravity = Gravity.LEFT
drawerLayout.addView(sidePanel, sideParams)
pcall(function()
  drawerLayout.setDrawerElevation(dp(14))
end)

menuBtn.setOnClickListener(View.OnClickListener{
  onClick = function()
    drawerLayout.openDrawer(sidePanel)
  end
})

closeBtn.setOnClickListener(View.OnClickListener{
  onClick = function()
    drawerLayout.closeDrawer(sidePanel)
  end
})

pcall(function()
  local BackGuard = luajava.bindClass("com.mini.luaxplus.BackGuard")
  BackGuard.install(activity)
  BackGuard.setHandler(activity, luajava.new(luajava.bindClass("java.lang.Runnable"), {
    run = function()
      if drawerLayout.isDrawerOpen(sidePanel) then
        drawerLayout.closeDrawer(sidePanel)
      else
        activity.finish()
      end
    end
  }))
end)

-- 左右滑动：向右打开侧栏，向左关闭侧栏
pcall(function()
  drawerLayout.setDrawerLockMode(DrawerLayout.LOCK_MODE_UNLOCKED)
end)

local swipeTracking = false
local swipeStartX = 0
local swipeStartY = 0

local function attachSwipe(view)
  view.setOnTouchListener(View.OnTouchListener{
    onTouch = function(v, event)
      local action = event.getAction()
      if action == 0 then
        swipeTracking = true
        swipeStartX = event.getX()
        swipeStartY = event.getY()
      elseif action == 2 and swipeTracking then
        local dx = event.getX() - swipeStartX
        local dy = event.getY() - swipeStartY
        if math.abs(dx) > dp(48) and math.abs(dx) > math.abs(dy) * 1.35 then
          swipeTracking = false
          if dx > 0 then
            drawerLayout.openDrawer(sidePanel)
          else
            drawerLayout.closeDrawer(sidePanel)
          end
        end
      elseif action == 1 or action == 3 then
        swipeTracking = false
      end
      return false
    end
  })
end

attachSwipe(scroll)
attachSwipe(sidePanel)

-- 外部目录被文件管理器或其它应用删除时，项目列表即时刷新
local projectObserver
local observerPending = false

local function scheduleProjectRefresh()
  if observerPending then
    return
  end
  observerPending = true
  activity.runOnUiThread(luajava.new(luajava.bindClass("java.lang.Runnable"), {
    run = function()
      observerPending = false
      pcall(refresh)
    end
  }))
end

pcall(function()
  projectObserver = LuaFileObserver(projectRoot, 0x00000f0a)
  projectObserver.setOnEventListener(luajava.new(
    luajava.bindClass("com.androlua.LuaFileObserver$OnEventListener"),
    {
      onEvent = function(event, path)
        scheduleProjectRefresh()
      end
    }
  ))
  projectObserver.startWatching()
end)

function onResume()
  pcall(refresh)
end

function onDestroy()
  pcall(function()
    if projectObserver then
      projectObserver.stopWatching()
    end
  end)
end

refresh()
