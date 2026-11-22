require "import"
import "android.app.*"
import "android.os.*"
import "android.widget.*"
import "android.view.*"
import "android.text.*"
import "android.graphics.drawable.*"
import "android.graphics.Typeface"
import "java.io.File"
import "com.google.android.material.dialog.MaterialAlertDialogBuilder"
import "com.google.android.material.materialswitch.MaterialSwitch"
import "loadbitmap"
import "autotheme"

-- 应用详情：属性 / 目录 / 权限 / 日志 四个页签

activity.setTheme(autotheme())

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
local LINE = 0xffe6dbc8

local args = {...}
local projectDir = args[1]
if type(projectDir) == "table" then
  projectDir = projectDir[1]
end
projectDir = tostring(projectDir or "")
projectDir = projectDir:gsub("/init%.lua$", "")

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

local function toast(text)
  Toast.makeText(activity, text, Toast.LENGTH_SHORT).show()
end

-- 运行前先编译校验，语法错误也能落快照，而不是只弹一个错误页
local function runScript(filePath)
  local ok, err = loadfile(filePath)
  if not ok then
    pcall(function()
      luajava.bindClass("com.mini.luaxplus.LogCore")
        .luaError("脚本语法错误 " .. tostring(filePath), tostring(err))
    end)
    toast("语法错误：" .. tostring(err))
    return
  end
  pcall(function()
    activity.newActivity(filePath)
  end)
end

local info = { path = projectDir }
pcall(function()
  local chunk = loadfile(projectDir .. "/init.lua", "bt", info)
  if chunk then
    chunk()
  end
end)
info.path = projectDir

local function writeInfo()
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
  local file = io.open(projectDir .. "/init.lua", "w")
  if not file then
    toast("写入失败，请检查存储权限")
    return false
  end
  file:write(table.concat(lines, "\n") .. "\n")
  file:close()
  return true
end

activity.setTitle(info.appname or "应用详情")

local root = LinearLayout(activity)
root.setOrientation(LinearLayout.VERTICAL)
root.setBackgroundColor(PAPER)
root.setFitsSystemWindows(true)
activity.setContentView(root)

-- 顶部信息
local header = LinearLayout(activity)
header.setOrientation(LinearLayout.HORIZONTAL)
header.setGravity(Gravity.CENTER_VERTICAL)
header.setPadding(dp(18), dp(14), dp(18), dp(10))

local icon = ImageView(activity)
local iconFile = File(projectDir .. "/icon.png")
if iconFile.exists() then
  icon.setImageBitmap(loadbitmap(iconFile.getAbsolutePath()))
else
  icon.setImageResource(R.drawable.icon)
end
icon.setScaleType(ImageView.ScaleType.CENTER_CROP)
icon.setBackground(rounded(0xfff2ece0, nil, 12))
header.addView(icon, LinearLayout.LayoutParams(dp(46), dp(46)))

local headerText = LinearLayout(activity)
headerText.setOrientation(LinearLayout.VERTICAL)
local headerParams = LinearLayout.LayoutParams(0, -2, 1)
headerParams.leftMargin = dp(12)
header.addView(headerText, headerParams)

local nameView = TextView(activity)
nameView.setText((info.appname or "未命名") .. "  v" .. (info.appver or "1.0"))
nameView.setTextSize(17)
nameView.setTypeface(Typeface.DEFAULT_BOLD)
nameView.setTextColor(INK)
headerText.addView(nameView)

local pkgView = TextView(activity)
pkgView.setText(info.packagename or "未设置包名")
pkgView.setTextSize(12)
pkgView.setTextColor(MUTED)
pkgView.setPadding(0, dp(3), 0, 0)
headerText.addView(pkgView)

root.addView(header, LinearLayout.LayoutParams(-1, -2))

-- 页签栏
local tabBar = LinearLayout(activity)
tabBar.setOrientation(LinearLayout.HORIZONTAL)
tabBar.setPadding(dp(14), 0, dp(14), 0)
root.addView(tabBar, LinearLayout.LayoutParams(-1, -2))

local tabViews = {}
local pageHolder = FrameLayout(activity)
root.addView(pageHolder, LinearLayout.LayoutParams(-1, 0, 1))

local pages = {}

local function makeScroll()
  local scroll = ScrollView(activity)
  scroll.setFillViewport(true)
  local box = LinearLayout(activity)
  box.setOrientation(LinearLayout.VERTICAL)
  box.setPadding(dp(18), dp(6), dp(18), dp(20))
  scroll.addView(box, LinearLayout.LayoutParams(-1, -2))
  scroll.tag = box
  return scroll, box
end

local currentTab = 1
local dirSyncNow

local function switchTab(index)
  currentTab = index
  for i = 1, #tabViews do
    if i == index then
      tabViews[i].setTextColor(0xff0b6f6a)
      tabViews[i].setTypeface(Typeface.DEFAULT_BOLD)
      tabViews[i].setBackground(rounded(0xffdff3f0, nil, 10))
    else
      tabViews[i].setTextColor(MUTED)
      tabViews[i].setTypeface(Typeface.DEFAULT)
      tabViews[i].setBackgroundColor(0x00000000)
    end
  end
  pageHolder.removeAllViews()
  pageHolder.addView(pages[index], FrameLayout.LayoutParams(-1, -1))
  if index == 2 and dirSyncNow then
    dirSyncNow()
  end
end

-- ===== 属性页 =====
local function buildInfoPage()
  local scroll, box = makeScroll()
  pages[1] = scroll

  local function section(title)
    local caption = TextView(activity)
    caption.setText(title)
    caption.setTextSize(11)
    caption.setTextColor(MUTED)
    caption.setTypeface(Typeface.DEFAULT_BOLD)
    caption.setPadding(dp(2), dp(18), 0, dp(2))
    box.addView(caption)
  end

  local function field(label, value, hint, multiline, numeric)
    local caption = TextView(activity)
    caption.setText(label)
    caption.setTextSize(12.5)
    caption.setTextColor(MUTED)
    caption.setPadding(dp(2), dp(9), 0, dp(4))
    box.addView(caption)

    local input = EditText(activity)
    input.setText(tostring(value or ""))
    input.setHint(hint or "")
    input.setTextSize(14)
    input.setTextColor(INK)
    input.setHintTextColor(0xFFA79B88)
    input.setBackground(rounded(CARD, LINE, 10))
    input.setPadding(dp(12), dp(9), dp(12), dp(9))
    if multiline then
      input.setSingleLine(false)
      input.setMinLines(3)
      input.setGravity(Gravity.TOP)
    else
      input.setSingleLine(true)
    end
    if numeric then
      input.setInputType(2)
    end
    box.addView(input, LinearLayout.LayoutParams(-1, -2))
    return input
  end

  section("基本信息")
  local nameInput = field("应用名称", info.appname, "显示在桌面上的名称")
  local pkgInput = field("包名", info.packagename, "例如 com.mini.demo")
  local verInput = field("版本号", info.appver, "例如 1.0")
  local codeInput = field("版本码", info.appcode, "整数，随版本递增", false, true)
  local sdkInput = field("最低 SDK", info.appsdk, "整数，例如 15", false, true)

  -- 主题、调试模式、渠道、密钥和路径匹配不再从属性页编辑，
  -- 仍保留在工程配置中，避免旧工程字段被写丢。
  section("说明")
  local developerInput = field("开发者", info.developer, "署名或团队名称")
  local descInput = field("简介", info.description, "一句话介绍这个应用", true)

  section("权限")
  local permRow = LinearLayout(activity)
  permRow.setOrientation(LinearLayout.HORIZONTAL)
  permRow.setGravity(Gravity.CENTER_VERTICAL)
  permRow.setPadding(dp(12), dp(11), dp(12), dp(11))
  permRow.setBackground(rounded(CARD, LINE, 10))
  box.addView(permRow, LinearLayout.LayoutParams(-1, -2))

  local permText = LinearLayout(activity)
  permText.setOrientation(LinearLayout.VERTICAL)
  permRow.addView(permText, LinearLayout.LayoutParams(0, -2, 1))
  local permTitle = TextView(activity)
  permTitle.setText("权限注入")
  permTitle.setTextSize(13.5)
  permTitle.setTextColor(INK)
  permText.addView(permTitle)
  local permHint = TextView(activity)
  permHint.setText("已选 " .. tostring(#(info.user_permission or {})) .. " 项，点此调整")
  permHint.setTextSize(11.5)
  permHint.setTextColor(MUTED)
  permHint.setPadding(0, dp(3), 0, 0)
  permText.addView(permHint)
  local permArrow = TextView(activity)
  permArrow.setText("›")
  permArrow.setTextSize(16)
  permArrow.setTextColor(MUTED)
  permRow.addView(permArrow)
  permRow.setOnClickListener(View.OnClickListener{
    onClick = function()
      switchTab(3)
    end
  })

  local pathCaption = TextView(activity)
  pathCaption.setText("工程目录：" .. projectDir)
  pathCaption.setTextSize(11.5)
  pathCaption.setTextColor(MUTED)
  pathCaption.setPadding(dp(2), dp(16), 0, 0)
  box.addView(pathCaption)

  local save = TextView(activity)
  save.setText("保存属性")
  save.setTextSize(14)
  save.setGravity(Gravity.CENTER)
  save.setTextColor(0xff0b6f6a)
  save.setBackground(rounded(0xffdff3f0, 0xffbfe6e1, 12))
  local saveParams = LinearLayout.LayoutParams(-1, dp(44))
  saveParams.topMargin = dp(18)
  box.addView(save, saveParams)

  local function textOf(input)
    return tostring(input.getText().toString()):match("^%s*(.-)%s*$")
  end

  save.setOnClickListener(View.OnClickListener{
    onClick = function()
      local appname = textOf(nameInput)
      local appver = textOf(verInput)
      local packagename = textOf(pkgInput)
      if appname == "" or appver == "" or packagename == "" then
        toast("应用名称、版本号和包名不能为空")
        return
      end
      local appcode = textOf(codeInput)
      local appsdk = textOf(sdkInput)
      if not appcode:match("^%d+$") or not appsdk:match("^%d+$") then
        toast("版本码和最低 SDK 必须是整数")
        return
      end

      info.appname = appname
      info.appver = appver
      info.packagename = packagename
      info.appcode = appcode
      info.appsdk = appsdk
      info.developer = textOf(developerInput)
      info.description = textOf(descInput)
      if writeInfo() then
        nameView.setText(info.appname .. "  v" .. info.appver)
        pkgView.setText(info.packagename)
        activity.setTitle(info.appname)
        toast("属性已保存")
      end
    end
  })
  return scroll
end

-- ===== 目录页 =====
local uiFile = projectDir .. "/.luaxplus.ui"
local uiState = {}
do
  local file = io.open(uiFile, "r")
  if file then
    for line in file:lines() do
      local key, value = line:match("^([%w_%-]+)=(.*)$")
      if key then
        uiState[key] = value
      end
    end
    file:close()
  end
end

local function saveUiState()
  local file = io.open(uiFile, "w")
  if not file then
    return
  end
  local lines = {}
  for key, value in pairs(uiState) do
    table.insert(lines, key .. "=" .. tostring(value))
  end
  file:write(table.concat(lines, "\n") .. "\n")
  file:close()
end

local SORT_MODES = {
  { key = "name", label = "名称" },
  { key = "time", label = "时间" },
  { key = "size", label = "大小" },
  { key = "type", label = "类型" },
}

local function sortLabel()
  for _, mode in ipairs(SORT_MODES) do
    if mode.key == uiState.sort then
      return mode.label
    end
  end
  return "名称"
end

local currentDir = projectDir
if uiState.lastDir and uiState.lastDir ~= ""
  and uiState.lastDir:sub(1, #projectDir) == projectDir
  and File(uiState.lastDir).isDirectory() then
  currentDir = uiState.lastDir
end

local dirQuery = ""
local lastDirSignature = nil
local dirRefresh

local function humanSize(bytes)
  if bytes < 1024 then
    return bytes .. " B"
  elseif bytes < 1024 * 1024 then
    return string.format("%.1f KB", bytes / 1024)
  end
  return string.format("%.1f MB", bytes / 1024 / 1024)
end

local function humanTime(millis)
  if not millis or millis <= 0 then
    return "未知时间"
  end
  local date = os.date("%Y-%m-%d %H:%M", math.floor(millis / 1000))
  return tostring(date)
end

local function fileTag(file)
  if file.isDirectory() then
    return "夹", 0xff7a6a56, 0xfff0e4d4
  end
  local name = file.getName():lower()
  if name:sub(-4) == ".lua" then
    return "L", 0xff0b6f6a, 0xffdff3f0
  elseif name:match("%.png$") or name:match("%.jpe?g$") or name:match("%.webp$") then
    return "图", 0xff4a6fa5, 0xffe2ecf8
  elseif name:match("%.alp$") or name:match("%.apk$") then
    return "包", 0xff8a5a2b, 0xfff7e6d2
  end
  return "文", 0xff5f6f7c, 0xffeceff2
end

-- 目录内容指纹：文件名 + 大小 + 修改时间，用来判断是否需要刷新
local function dirSignature(dir)
  local files = File(dir).listFiles()
  if not files then
    return ""
  end
  local parts = {}
  for i = 0, #files - 1 do
    table.insert(parts, files[i].getName() .. ":" .. files[i].length() .. ":" .. files[i].lastModified())
  end
  table.sort(parts)
  return table.concat(parts, "|")
end

local function collectEntries()
  local files = File(currentDir).listFiles()
  local entries = {}
  if files then
    for i = 0, #files - 1 do
      local name = files[i].getName()
      if name:sub(1, 1) ~= "." then
        table.insert(entries, files[i])
      end
    end
  end
  if dirQuery ~= "" then
    local keyword = dirQuery:lower()
    local filtered = {}
    for _, item in ipairs(entries) do
      if item.getName():lower():find(keyword, 1, true) then
        table.insert(filtered, item)
      end
    end
    entries = filtered
  end
  local mode = uiState.sort or "name"
  table.sort(entries, function(a, b)
    if a.isDirectory() ~= b.isDirectory() then
      return a.isDirectory()
    end
    if mode == "time" then
      if a.lastModified() ~= b.lastModified() then
        return a.lastModified() > b.lastModified()
      end
    elseif mode == "size" then
      if a.length() ~= b.length() then
        return a.length() > b.length()
      end
    elseif mode == "type" then
      local ea = a.getName():match("%.([%w]+)$") or ""
      local eb = b.getName():match("%.([%w]+)$") or ""
      if ea ~= eb then
        return ea < eb
      end
    end
    return a.getName():lower() < b.getName():lower()
  end)
  return entries
end

local function openEditor(filePath)
  pcall(function()
    activity.newActivity("editor", {filePath})
  end)
end

local function removePath(path)
  local file = File(path)
  if file.isDirectory() then
    local children = file.listFiles()
    if children then
      for i = 0, #children - 1 do
        removePath(children[i].getAbsolutePath())
      end
    end
  end
  file.delete()
end

local function deleteFile(filePath)
  MaterialAlertDialogBuilder(activity)
    .setTitle("删除")
    .setMessage("确定删除 " .. File(filePath).getName() .. "？")
    .setNegativeButton("取消", nil)
    .setPositiveButton("删除", function()
      removePath(filePath)
      toast("已删除")
      dirRefresh(true)
    end)
    .show()
end

local function renameFile(filePath)
  local input = EditText(activity)
  input.setText(File(filePath).getName())
  input.setSingleLine(true)
  MaterialAlertDialogBuilder(activity)
    .setTitle("重命名")
    .setView(input)
    .setNegativeButton("取消", nil)
    .setPositiveButton("确定", function()
      local name = tostring(input.getText().toString()):match("^%s*(.-)%s*$")
      if name == "" then
        toast("名称不能为空")
        return
      end
      local target = File(filePath).getParentFile().getAbsolutePath() .. "/" .. name
      if File(target).exists() then
        toast("同名文件已存在")
        return
      end
      if File(filePath).renameTo(File(target)) then
        toast("已重命名")
        dirRefresh(true)
      else
        toast("重命名失败")
      end
    end)
    .show()
end

local function showDetails(filePath)
  local file = File(filePath)
  local message = "名称：" .. file.getName()
    .. "\n路径：" .. file.getAbsolutePath()
  if file.isDirectory() then
    local children = file.listFiles()
    message = message .. "\n类型：文件夹（" .. tostring(children and #children or 0) .. " 项）"
  else
    message = message .. "\n大小：" .. humanSize(file.length())
  end
  message = message .. "\n修改时间：" .. humanTime(file.lastModified())
  MaterialAlertDialogBuilder(activity)
    .setTitle("文件详情")
    .setMessage(message)
    .setPositiveButton("知道了", nil)
    .show()
end

local function goUp()
  local parent = File(currentDir).getParentFile()
  if parent and File(parent.getAbsolutePath()).isDirectory()
    and parent.getAbsolutePath():sub(1, #projectDir) == projectDir then
    currentDir = parent.getAbsolutePath()
    uiState.lastDir = currentDir
    saveUiState()
    dirRefresh()
  end
end

local function showFileMenu(filePath, isDir)
  local options
  if isDir then
    options = { "进入", "重命名", "详情", "删除" }
  else
    options = { "编辑", "运行", "重命名", "详情", "删除" }
  end
  MaterialAlertDialogBuilder(activity)
    .setTitle(File(filePath).getName())
    .setItems(options, function(dialog, which)
      local choice = options[which + 1]
      if choice == "进入" then
        currentDir = filePath
        uiState.lastDir = currentDir
        saveUiState()
        dirRefresh()
      elseif choice == "编辑" then
        openEditor(filePath)
      elseif choice == "运行" then
        runScript(filePath)
      elseif choice == "重命名" then
        renameFile(filePath)
      elseif choice == "详情" then
        showDetails(filePath)
      elseif choice == "删除" then
        deleteFile(filePath)
      end
    end)
    .show()
end

local function promptCreate(title, hint, isDir)
  local input = EditText(activity)
  input.setHint(hint)
  input.setSingleLine(true)
  MaterialAlertDialogBuilder(activity)
    .setTitle(title)
    .setView(input)
    .setNegativeButton("取消", nil)
    .setPositiveButton("创建", function()
      local name = tostring(input.getText().toString()):match("^%s*(.-)%s*$")
      if name == "" then
        return
      end
      local target = currentDir .. "/" .. name
      if File(target).exists() then
        toast("同名" .. (isDir and "文件夹" or "文件") .. "已存在")
        return
      end
      local ok
      if isDir then
        ok = File(target).mkdirs()
      else
        local out = io.open(target, "w")
        if out then
          out:write("")
          out:close()
          ok = true
        end
      end
      if ok then
        toast("已创建 " .. name)
        dirRefresh(true)
      else
        toast("创建失败，请检查存储权限")
      end
    end)
    .show()
end

local dirRows
local dirEmpty
local dirCount

local function renderEntries()
  if not dirRows then
    return
  end
  dirRows.removeAllViews()
  local entries = collectEntries()
  if dirCount then
    dirCount.setText("共 " .. #entries .. " 项 · 按" .. sortLabel() .. "排序")
  end

  if #entries == 0 then
    if not dirEmpty then
      dirEmpty = LinearLayout(activity)
      dirEmpty.setOrientation(LinearLayout.VERTICAL)
      dirEmpty.setGravity(Gravity.CENTER)
      dirEmpty.setPadding(0, dp(28), 0, dp(28))
      local emptyTitle = TextView(activity)
      emptyTitle.setText(dirQuery ~= "" and "没有匹配的文件" or "这里还没有文件")
      emptyTitle.setTextSize(14)
      emptyTitle.setTextColor(INK)
      emptyTitle.setGravity(Gravity.CENTER)
      dirEmpty.addView(emptyTitle)
      local emptyHint = TextView(activity)
      emptyHint.setText(dirQuery ~= "" and "换个关键词，或清空搜索" or "用上方按钮新建文件或文件夹")
      emptyHint.setTextSize(11.5)
      emptyHint.setTextColor(MUTED)
      emptyHint.setGravity(Gravity.CENTER)
      emptyHint.setPadding(0, dp(6), 0, 0)
      dirEmpty.addView(emptyHint)
    end
    dirRows.addView(dirEmpty, LinearLayout.LayoutParams(-1, -2))
    return
  end

  for _, item in ipairs(entries) do
    local path = item.getAbsolutePath()
    local row = LinearLayout(activity)
    row.setOrientation(LinearLayout.HORIZONTAL)
    row.setGravity(Gravity.CENTER_VERTICAL)
    row.setPadding(dp(11), dp(10), dp(11), dp(10))
    row.setBackground(rounded(CARD, LINE, 12))
    local rowParams = LinearLayout.LayoutParams(-1, -2)
    rowParams.topMargin = dp(7)
    dirRows.addView(row, rowParams)

    local tagText, tagColor, tagBg = fileTag(item)
    local badge = TextView(activity)
    badge.setText(tagText)
    badge.setTextSize(11)
    badge.setGravity(Gravity.CENTER)
    badge.setTextColor(tagColor)
    badge.setBackground(rounded(tagBg, nil, 8))
    row.addView(badge, LinearLayout.LayoutParams(dp(28), dp(28)))

    local label = LinearLayout(activity)
    label.setOrientation(LinearLayout.VERTICAL)
    local labelParams = LinearLayout.LayoutParams(0, -2, 1)
    labelParams.leftMargin = dp(10)
    row.addView(label, labelParams)

    local fileName = TextView(activity)
    fileName.setText(item.getName())
    fileName.setTextSize(13.5)
    fileName.setTextColor(INK)
    fileName.setSingleLine(true)
    fileName.setEllipsize(TextUtils.TruncateAt.END)
    label.addView(fileName)

    local meta = TextView(activity)
    if item.isDirectory() then
      meta.setText("文件夹 · " .. humanTime(item.lastModified()))
    else
      meta.setText(humanSize(item.length()) .. " · " .. humanTime(item.lastModified()))
    end
    meta.setTextSize(11)
    meta.setTextColor(MUTED)
    meta.setPadding(0, dp(3), 0, 0)
    label.addView(meta)

    local more = TextView(activity)
    more.setText("⋯")
    more.setTextSize(15)
    more.setTextColor(MUTED)
    more.setGravity(Gravity.CENTER)
    more.setPadding(dp(6), dp(4), dp(2), dp(4))
    row.addView(more)

    row.setOnClickListener(View.OnClickListener{
      onClick = function()
        if item.isDirectory() then
          currentDir = path
          uiState.lastDir = currentDir
          saveUiState()
          dirRefresh()
        else
          openEditor(path)
        end
      end
    })
    row.setOnLongClickListener(View.OnLongClickListener{
      onLongClick = function()
        showFileMenu(path, item.isDirectory())
        return true
      end
    })
    more.setOnClickListener(View.OnClickListener{
      onClick = function()
        showFileMenu(path, item.isDirectory())
      end
    })
  end
end

function buildDirPage(keepPage)
  local previousScroll = 0
  if keepPage and pages[2] then
    pcall(function()
      previousScroll = pages[2].getScrollY()
    end)
  end
  local scroll, box = makeScroll()
  dirEmpty = nil
  if not keepPage or not pages[2] then
    pages[2] = scroll
  else
    local old = pages[2]
    pages[2] = scroll
    if pageHolder.getChildAt(0) == old then
      pageHolder.removeAllViews()
      pageHolder.addView(scroll, FrameLayout.LayoutParams(-1, -1))
    end
  end

  -- 面包屑
  local crumbScroll = HorizontalScrollView(activity)
  crumbScroll.setHorizontalScrollBarEnabled(false)
  box.addView(crumbScroll, LinearLayout.LayoutParams(-1, -2))
  local crumbRow = LinearLayout(activity)
  crumbRow.setOrientation(LinearLayout.HORIZONTAL)
  crumbRow.setGravity(Gravity.CENTER_VERTICAL)
  crumbScroll.addView(crumbRow, LinearLayout.LayoutParams(-2, -2))

  local crumbs = { { "工程", projectDir } }
  local relative = currentDir:sub(#projectDir + 1):gsub("^/+", "")
  if relative ~= "" then
    local path = projectDir
    for segment in relative:gmatch("[^/]+") do
      path = path .. "/" .. segment
      table.insert(crumbs, { segment, path })
    end
  end

  for index, crumb in ipairs(crumbs) do
    local chip = TextView(activity)
    chip.setText(crumb[1])
    chip.setTextSize(12)
    chip.setSingleLine(true)
    if index == #crumbs then
      chip.setTextColor(INK)
      chip.setTypeface(Typeface.DEFAULT_BOLD)
      chip.setBackground(rounded(0xfff2ece0, nil, 8))
    else
      chip.setTextColor(0xff0b6f6a)
      chip.setBackground(rounded(0x00000000, nil, 8))
    end
    chip.setPadding(dp(7), dp(4), dp(7), dp(4))
    local chipParams = LinearLayout.LayoutParams(-2, -2)
    chipParams.rightMargin = dp(2)
    crumbRow.addView(chip, chipParams)
    local target = crumb[2]
    chip.setOnClickListener(View.OnClickListener{
      onClick = function()
        currentDir = target
        uiState.lastDir = currentDir
        saveUiState()
        dirRefresh()
      end
    })
    if index < #crumbs then
      local sep = TextView(activity)
      sep.setText("/")
      sep.setTextSize(11)
      sep.setTextColor(MUTED)
      crumbRow.addView(sep)
    end
  end

  crumbScroll.post(luajava.new(luajava.bindClass("java.lang.Runnable"), {
    run = function()
      crumbScroll.fullScroll(View.FOCUS_RIGHT)
    end
  }))

  -- 搜索框
  local searchRow = LinearLayout(activity)
  searchRow.setOrientation(LinearLayout.HORIZONTAL)
  searchRow.setGravity(Gravity.CENTER_VERTICAL)
  searchRow.setBackground(rounded(CARD, LINE, 10))
  searchRow.setPadding(dp(10), 0, dp(10), 0)
  local searchParams = LinearLayout.LayoutParams(-1, dp(38))
  searchParams.topMargin = dp(10)
  box.addView(searchRow, searchParams)

  local searchIcon = TextView(activity)
  searchIcon.setText("⌕")
  searchIcon.setTextSize(15)
  searchIcon.setTextColor(MUTED)
  searchRow.addView(searchIcon)

  local searchInput = EditText(activity)
  searchInput.setHint("搜索当前目录")
  searchInput.setText(dirQuery)
  searchInput.setTextSize(13)
  searchInput.setTextColor(INK)
  searchInput.setHintTextColor(0xFFA79B88)
  searchInput.setBackgroundColor(0x00000000)
  searchInput.setSingleLine(true)
  searchInput.setPadding(dp(6), 0, dp(4), 0)
  searchRow.addView(searchInput, LinearLayout.LayoutParams(0, -1, 1))
  searchInput.addTextChangedListener(TextWatcher{
    beforeTextChanged = function()
    end,
    onTextChanged = function()
    end,
    afterTextChanged = function(editable)
      dirQuery = tostring(editable.toString())
      renderEntries()
    end
  })

  -- 操作条
  local actions = LinearLayout(activity)
  actions.setOrientation(LinearLayout.HORIZONTAL)
  local actionsParams = LinearLayout.LayoutParams(-1, -2)
  actionsParams.topMargin = dp(10)
  box.addView(actions, actionsParams)

  local function actionButton(text, handler)
    local button = TextView(activity)
    button.setText(text)
    button.setTextSize(12)
    button.setTextColor(0xff0b6f6a)
    button.setGravity(Gravity.CENTER)
    button.setPadding(dp(9), dp(6), dp(9), dp(6))
    button.setBackground(rounded(0xffdff3f0, 0xffbfe6e1, 9))
    local params = LinearLayout.LayoutParams(-2, -2)
    params.rightMargin = dp(7)
    actions.addView(button, params)
    button.setOnClickListener(View.OnClickListener{
      onClick = handler
    })
    return button
  end

  if currentDir ~= projectDir then
    actionButton("↑ 上级", function()
      goUp()
    end)
  end
  actionButton("+ 文件", function()
    promptCreate("新建文件", "例如 page.lua", false)
  end)
  actionButton("+ 文件夹", function()
    promptCreate("新建文件夹", "例如 pages", true)
  end)
  actionButton("刷新", function()
    dirRefresh(true)
  end)
  actionButton("排序", function()
    local currentKey = uiState.sort or "name"
    local nextKey = "name"
    for index, mode in ipairs(SORT_MODES) do
      if mode.key == currentKey then
        nextKey = SORT_MODES[(index % #SORT_MODES) + 1].key
        break
      end
    end
    uiState.sort = nextKey
    saveUiState()
    renderEntries()
    toast("已按" .. sortLabel() .. "排序")
  end)

  dirCount = TextView(activity)
  dirCount.setTextSize(10.5)
  dirCount.setTextColor(MUTED)
  dirCount.setPadding(dp(2), dp(10), 0, 0)
  box.addView(dirCount)

  dirRows = LinearLayout(activity)
  dirRows.setOrientation(LinearLayout.VERTICAL)
  box.addView(dirRows, LinearLayout.LayoutParams(-1, -2))

  -- 操作后的统一刷新入口，保证页面可见时立即更新
  dirRefresh = function(keepPage)
    buildDirPage(true)
  end

  lastDirSignature = dirSignature(currentDir)
  renderEntries()
  if previousScroll > 0 then
    scroll.post(luajava.new(luajava.bindClass("java.lang.Runnable"), {
      run = function()
        scroll.scrollTo(0, previousScroll)
      end
    }))
  end
  return scroll
end

dirSyncNow = function()
  if pages[2] and lastDirSignature and dirSignature(currentDir) ~= lastDirSignature then
    buildDirPage(true)
  end
end

-- ===== 权限页 =====
local PERMISSION_GROUPS = {
  { title = "存储", items = {
      { "读写存储", "WRITE_EXTERNAL_STORAGE" },
      { "读取存储", "READ_EXTERNAL_STORAGE" },
      { "所有文件访问", "MANAGE_EXTERNAL_STORAGE" },
  } },
  { title = "网络", items = {
      { "联网", "INTERNET" },
      { "网络状态", "ACCESS_NETWORK_STATE" },
      { "无线状态", "ACCESS_WIFI_STATE" },
  } },
  { title = "相机与录音", items = {
      { "相机", "CAMERA" },
      { "录音", "RECORD_AUDIO" },
  } },
  { title = "位置", items = {
      { "精确定位", "ACCESS_FINE_LOCATION" },
      { "粗略定位", "ACCESS_COARSE_LOCATION" },
  } },
  { title = "通讯与信息", items = {
      { "读取联系人", "READ_CONTACTS" },
      { "读取短信", "READ_SMS" },
      { "发送短信", "SEND_SMS" },
      { "拨打电话", "CALL_PHONE" },
  } },
  { title = "系统与界面", items = {
      { "通知", "POST_NOTIFICATIONS" },
      { "悬浮窗", "SYSTEM_ALERT_WINDOW" },
      { "震动", "VIBRATE" },
      { "后台常驻", "WAKE_LOCK" },
      { "前台服务", "FOREGROUND_SERVICE" },
  } },
}

local function declaredPermissions()
  local set = {}
  for _, item in ipairs(info.user_permission or {}) do
    set[(item:gsub("android%.permission%.", ""))] = true
  end
  return set
end

local function buildPermissionPage()
  local scroll, box = makeScroll()
  pages[3] = scroll

  local note = TextView(activity)
  note.setText("勾选的权限会在打包时写进成品清单，未勾选的不会出现。默认至少保留存储与联网，用于日志与基础功能。")
  note.setTextSize(12.5)
  note.setTextColor(MUTED)
  note.setBackground(rounded(0xfff3f6f9, 0xffd8e3ec, 10))
  note.setPadding(dp(12), dp(10), dp(12), dp(10))
  box.addView(note, LinearLayout.LayoutParams(-1, -2))

  local current = declaredPermissions()
  local switches = {}

  for _, group in ipairs(PERMISSION_GROUPS) do
    local caption = TextView(activity)
    caption.setText(group.title)
    caption.setTextSize(13)
    caption.setTypeface(Typeface.DEFAULT_BOLD)
    caption.setTextColor(0xff16324a)
    caption.setPadding(dp(2), dp(16), 0, dp(6))
    box.addView(caption)

    for _, entry in ipairs(group.items) do
      local row = LinearLayout(activity)
      row.setOrientation(LinearLayout.HORIZONTAL)
      row.setGravity(Gravity.CENTER_VERTICAL)
      row.setPadding(dp(12), dp(8), dp(12), dp(8))
      row.setBackground(rounded(CARD, LINE, 10))
      local rowParams = LinearLayout.LayoutParams(-1, -2)
      rowParams.topMargin = dp(6)
      box.addView(row, rowParams)

      local label = TextView(activity)
      label.setText(entry[1])
      label.setTextSize(13.5)
      label.setTextColor(INK)
      row.addView(label, LinearLayout.LayoutParams(0, -2, 1))

      local toggle = MaterialSwitch(activity)
      if current[entry[2]] then
        toggle.setChecked(true)
      else
        toggle.setChecked(false)
      end
      row.addView(toggle)
      toggle.setOnCheckedChangeListener(CompoundButton.OnCheckedChangeListener{
        onCheckedChanged = function(button, state)
          switches[entry[2]] = state
        end
      })
      if current[entry[2]] then
        switches[entry[2]] = true
      else
        switches[entry[2]] = false
      end

      row.setOnClickListener(View.OnClickListener{
        onClick = function()
          toggle.setChecked(not toggle.isChecked())
        end
      })
    end
  end

  local save = TextView(activity)
  save.setText("保存权限注入")
  save.setTextSize(14)
  save.setGravity(Gravity.CENTER)
  save.setTextColor(0xff0b6f6a)
  save.setBackground(rounded(0xffdff3f0, 0xffbfe6e1, 12))
  local saveParams = LinearLayout.LayoutParams(-1, dp(44))
  saveParams.topMargin = dp(18)
  box.addView(save, saveParams)
  save.setOnClickListener(View.OnClickListener{
    onClick = function()
      local selected = {}
      for _, group in ipairs(PERMISSION_GROUPS) do
        for _, entry in ipairs(group.items) do
          if switches[entry[2]] then
            table.insert(selected, "android.permission." .. entry[2])
          end
        end
      end
      if #selected == 0 then
        selected = { "android.permission.INTERNET", "android.permission.WRITE_EXTERNAL_STORAGE" }
      end
      info.user_permission = selected
      info.strict_permissions = true
      writeInfo()
      toast("权限已保存，打包时生效")
    end
  })
  return scroll
end

-- ===== 日志页 =====
local function readHead(path, count)
  local file = io.open(path, "r")
  if not file then
    return ""
  end
  local lines = {}
  for _ = 1, (count or 6) do
    local line = file:read("*l")
    if not line then
      break
    end
    table.insert(lines, line)
  end
  file:close()
  return table.concat(lines, "\n")
end

local function collectLogs()
  local dirs = {
    activity.getLuaExtDir() .. "/logs",
    activity.getLuaExtDir() .. "/products/" .. (info.packagename or "") .. "/logs",
  }
  local list = {}
  for _, dir in ipairs(dirs) do
    local files = File(dir).listFiles()
    if files then
      for i = 0, #files - 1 do
        local item = files[i]
        if item.isFile() then
          table.insert(list, item)
        end
      end
    end
  end
  table.sort(list, function(a, b)
    return a.lastModified() > b.lastModified()
  end)
  return list
end

local function buildLogPage()
  local scroll, box = makeScroll()
  pages[4] = scroll

  local card = LinearLayout(activity)
  card.setOrientation(LinearLayout.VERTICAL)
  card.setGravity(Gravity.CENTER)
  card.setPadding(dp(20), dp(46), dp(20), dp(46))
  card.setBackground(rounded(CARD, LINE, 14))
  box.addView(card, LinearLayout.LayoutParams(-1, -2))

  local symbol = TextView(activity)
  symbol.setText("志")
  symbol.setTextSize(20)
  symbol.setTextColor(0xff7a6a56)
  symbol.setGravity(Gravity.CENTER)
  symbol.setBackground(rounded(0xfff2ece0, nil, 14))
  card.addView(symbol, LinearLayout.LayoutParams(dp(52), dp(52)))

  local title = TextView(activity)
  title.setText("日志页占位")
  title.setTextSize(15)
  title.setTextColor(INK)
  title.setGravity(Gravity.CENTER)
  title.setPadding(0, dp(14), 0, dp(6))
  card.addView(title)

  local hint = TextView(activity)
  hint.setText("这里先留空，日志的展示方式与内容待确认后接入。")
  hint.setTextSize(12.5)
  hint.setTextColor(MUTED)
  hint.setGravity(Gravity.CENTER)
  card.addView(hint, LinearLayout.LayoutParams(-1, -2))

  return scroll
end

-- 页签装配
local tabNames = { "属性", "目录", "权限", "日志" }
for i = 1, #tabNames do
  local tab = TextView(activity)
  tab.setText(tabNames[i])
  tab.setTextSize(13.5)
  tab.setGravity(Gravity.CENTER)
  tab.setPadding(dp(12), dp(8), dp(12), dp(8))
  local params = LinearLayout.LayoutParams(-2, -2)
  params.rightMargin = dp(8)
  tabBar.addView(tab, params)
  tabViews[i] = tab
  tab.setOnClickListener(View.OnClickListener{
    onClick = function()
      switchTab(i)
    end
  })
end

pages[1] = buildInfoPage()
pages[2] = buildDirPage()
pages[3] = buildPermissionPage()
pages[4] = buildLogPage()

-- 停留目录页时轮询指纹，外部改动（其他 App、电脑拷入）也能立刻刷新
local dirHandler = Handler(Looper.getMainLooper())
local dirTicker
dirTicker = luajava.new(luajava.bindClass("java.lang.Runnable"), {
  run = function()
    local alive = true
    pcall(function()
      alive = not activity.isFinishing()
    end)
    if not alive then
      return
    end
    if currentTab == 2 then
      dirSyncNow()
    end
    pcall(function()
      dirHandler.postDelayed(dirTicker, 1500)
    end)
  end
})
pcall(function()
  dirHandler.postDelayed(dirTicker, 1500)
end)

pcall(function()
  local BackGuard = luajava.bindClass("com.mini.luaxplus.BackGuard")
  BackGuard.install(activity)
  BackGuard.setHandler(activity, luajava.new(luajava.bindClass("java.lang.Runnable"), {
    run = function()
      if currentTab == 2 and currentDir ~= projectDir then
        goUp()
      else
        activity.finish()
      end
    end
  }))
end)

switchTab(1)

-- 底部操作条
local bar = LinearLayout(activity)
bar.setOrientation(LinearLayout.HORIZONTAL)
bar.setPadding(dp(14), dp(8), dp(14), dp(12))
bar.setBackgroundColor(PAPER)
root.addView(bar, LinearLayout.LayoutParams(-1, -2))

local function barButton(text, primary, handler)
  local button = TextView(activity)
  button.setText(text)
  button.setTextSize(14)
  button.setGravity(Gravity.CENTER)
  if primary then
    button.setTextColor(0xff0b6f6a)
    button.setBackground(rounded(0xffdff3f0, 0xffbfe6e1, 12))
  else
    button.setTextColor(INK)
    button.setBackground(rounded(CARD, LINE, 12))
  end
  local params = LinearLayout.LayoutParams(0, dp(44), 1)
  params.rightMargin = dp(8)
  bar.addView(button, params)
  button.setOnClickListener(View.OnClickListener{
    onClick = handler
  })
end

barButton("运行", false, function()
  local entry = projectDir .. "/main.lua"
  if not File(entry).exists() then
    toast("缺少 main.lua")
    return
  end
  runScript(entry)
end)

barButton("打包", true, function()
  local ok, err = pcall(function()
    local bin = require "bin"
    bin(projectDir .. "/")
  end)
  if not ok then
    pcall(function()
      luajava.bindClass("com.mini.luaxplus.LogCore")
        .luaError("打包调用失败 " .. projectDir, tostring(err))
    end)
    toast("打包失败：" .. tostring(err))
  end
end)

barButton("编辑器", false, function()
  pcall(function()
    activity.newActivity("editor", {projectDir .. "/main.lua"})
  end)
end)
