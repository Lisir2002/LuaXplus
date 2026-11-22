require "import"
import "android.app.*"
import "android.os.*"
import "android.widget.*"
import "android.view.*"
import "android.graphics.drawable.*"
import "android.graphics.Typeface"
import "java.io.File"
import "com.google.android.material.dialog.MaterialAlertDialogBuilder"
import "com.google.android.material.materialswitch.MaterialSwitch"
import "loadbitmap"
import "autotheme"

-- 应用详情：属性 / 目录 / 权限 / 日志 四个页签

activity.setTheme(autotheme())

local PAPER = 0xfff7f1e6
local CARD = 0xfffdf8
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
  local file = io.open(projectDir .. "/init.lua", "w")
  file:write("appname=" .. string.format("%q", info.appname or "未命名") .. "\n")
  file:write("appver=" .. string.format("%q", info.appver or "1.0") .. "\n")
  file:write("packagename=" .. string.format("%q", info.packagename or "com.mini.app") .. "\n")
  file:write("developer=" .. string.format("%q", info.developer or "") .. "\n")
  file:write("description=" .. string.format("%q", info.description or "") .. "\n")
  local permissions = {}
  for _, item in ipairs(info.user_permission or {}) do
    table.insert(permissions, string.format("%q", item))
  end
  file:write("user_permission={" .. table.concat(permissions, ",") .. "}\n")
  if info.strict_permissions then
    file:write("strict_permissions=true\n")
  end
  file:close()
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

local function switchTab(index)
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
end

-- ===== 属性页 =====
local function buildInfoPage()
  local scroll, box = makeScroll()
  pages[1] = scroll

  local function field(label, value, multiline)
    local caption = TextView(activity)
    caption.setText(label)
    caption.setTextSize(12.5)
    caption.setTextColor(MUTED)
    caption.setPadding(dp(2), dp(10), 0, dp(4))
    box.addView(caption)

    local input = EditText(activity)
    input.setText(value or "")
    input.setTextSize(14)
    input.setTextColor(INK)
    input.setBackground(rounded(CARD, LINE, 10))
    input.setPadding(dp(12), dp(9), dp(12), dp(9))
    if multiline then
      input.setSingleLine(false)
      input.setMinLines(3)
      input.setGravity(Gravity.TOP)
    else
      input.setSingleLine(true)
    end
    box.addView(input, LinearLayout.LayoutParams(-1, -2))
    return input
  end

  local nameInput = field("应用名称", info.appname)
  local pkgInput = field("包名", info.packagename)
  local verInput = field("版本号", info.appver)
  local developerInput = field("开发者", info.developer)
  local descInput = field("简介", info.description, true)

  local pathCaption = TextView(activity)
  pathCaption.setText("工程目录：" .. projectDir)
  pathCaption.setTextSize(12)
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
  save.setOnClickListener(View.OnClickListener{
    onClick = function()
      info.appname = nameInput.getText().toString()
      info.packagename = pkgInput.getText().toString()
      info.appver = verInput.getText().toString()
      info.developer = developerInput.getText().toString()
      info.description = descInput.getText().toString()
      writeInfo()
      nameView.setText(info.appname .. "  v" .. info.appver)
      pkgView.setText(info.packagename)
      toast("属性已保存")
    end
  })
  return scroll
end

-- ===== 目录页 =====
local currentDir = projectDir

local function humanSize(bytes)
  if bytes < 1024 then
    return bytes .. " B"
  elseif bytes < 1024 * 1024 then
    return string.format("%.1f KB", bytes / 1024)
  end
  return string.format("%.1f MB", bytes / 1024 / 1024)
end

local function openEditor(filePath)
  pcall(function()
    activity.newActivity("editor", {filePath})
  end)
end

local function deleteFile(filePath)
  MaterialAlertDialogBuilder(activity)
    .setTitle("删除")
    .setMessage("确定删除 " .. File(filePath).getName() .. "？")
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
      drop(filePath)
      toast("已删除")
      buildDirPage(true)
    end)
    .show()
end

local function showFileMenu(filePath, isDir)
  local options
  if isDir then
    options = { "进入", "删除" }
  else
    options = { "编辑", "运行", "删除" }
  end
  MaterialAlertDialogBuilder(activity)
    .setTitle(File(filePath).getName())
    .setItems(options, function(dialog, which)
      local choice = options[which + 1]
      if choice == "进入" then
        currentDir = filePath
        buildDirPage()
      elseif choice == "编辑" then
        openEditor(filePath)
      elseif choice == "运行" then
        runScript(filePath)
      elseif choice == "删除" then
        deleteFile(filePath)
      end
    end)
    .show()
end

local dirScroll
function buildDirPage(keepPage)
  local scroll, box = makeScroll()
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
  dirScroll = scroll

  local breadcrumb = TextView(activity)
  local crumb = currentDir:gsub(projectDir, "工程根目录")
  breadcrumb.setText((crumb))
  breadcrumb.setTextSize(12)
  breadcrumb.setTextColor(MUTED)
  breadcrumb.setPadding(dp(2), dp(6), dp(2), dp(10))
  box.addView(breadcrumb)

  local actions = LinearLayout(activity)
  actions.setOrientation(LinearLayout.HORIZONTAL)
  box.addView(actions, LinearLayout.LayoutParams(-1, -2))

  local function actionButton(text, handler)
    local button = TextView(activity)
    button.setText(text)
    button.setTextSize(13)
    button.setTextColor(0xff0b6f6a)
    button.setGravity(Gravity.CENTER)
    button.setPadding(dp(12), dp(7), dp(12), dp(7))
    button.setBackground(rounded(0xffdff3f0, 0xffbfe6e1, 10))
    local params = LinearLayout.LayoutParams(-2, -2)
    params.rightMargin = dp(8)
    actions.addView(button, params)
    button.setOnClickListener(View.OnClickListener{
      onClick = handler
    })
    return button
  end

  if currentDir ~= projectDir then
    actionButton("返回上级", function()
      currentDir = File(currentDir).getParent()
      buildDirPage()
    end)
  end

  actionButton("新建文件", function()
    local input = EditText(activity)
    input.setHint("文件名，例如 page.lua")
    MaterialAlertDialogBuilder(activity)
      .setTitle("新建文件")
      .setView(input)
      .setNegativeButton("取消", nil)
      .setPositiveButton("创建", function()
        local name = tostring(input.getText().toString())
        if name == "" then
          return
        end
        local target = currentDir .. "/" .. name
        if File(target).exists() then
          toast("同名文件已存在")
          return
        end
        local out = io.open(target, "w")
        if not out then
          toast("创建失败，请检查存储权限")
          return
        end
        out:write("")
        out:close()
        buildDirPage(true)
        toast("已创建 " .. name)
      end)
      .show()
  end)

  actionButton("新建文件夹", function()
    local input = EditText(activity)
    input.setHint("文件夹名")
    MaterialAlertDialogBuilder(activity)
      .setTitle("新建文件夹")
      .setView(input)
      .setNegativeButton("取消", nil)
      .setPositiveButton("创建", function()
        local name = tostring(input.getText().toString())
        if name == "" then
          return
        end
        local target = File(currentDir .. "/" .. name)
        if target.exists() then
          toast("同名文件夹已存在")
          return
        end
        if target.mkdirs() then
          buildDirPage(true)
          toast("已创建 " .. name)
        else
          toast("创建失败，请检查存储权限")
        end
      end)
      .show()
  end)

  local files = File(currentDir).listFiles()
  local entries = {}
  if files then
    for i = 0, #files - 1 do
      table.insert(entries, files[i])
    end
  end
  table.sort(entries, function(a, b)
    if a.isDirectory() ~= b.isDirectory() then
      return a.isDirectory()
    end
    return a.getName():lower() < b.getName():lower()
  end)

  for i = 1, #entries do
    local item = entries[i]
    local row = LinearLayout(activity)
    row.setOrientation(LinearLayout.HORIZONTAL)
    row.setGravity(Gravity.CENTER_VERTICAL)
    row.setPadding(dp(12), dp(11), dp(12), dp(11))
    row.setBackground(rounded(CARD, LINE, 12))
    local rowParams = LinearLayout.LayoutParams(-1, -2)
    rowParams.topMargin = dp(8)
    box.addView(row, rowParams)

    local symbol = TextView(activity)
    symbol.setText(item.isDirectory() and "夹" or "文")
    symbol.setTextSize(11)
    symbol.setGravity(Gravity.CENTER)
    symbol.setTextColor(0xff7a6a56)
    symbol.setBackground(rounded(0xfff2ece0, nil, 8))
    row.addView(symbol, LinearLayout.LayoutParams(dp(26), dp(26)))

    local label = LinearLayout(activity)
    label.setOrientation(LinearLayout.VERTICAL)
    local labelParams = LinearLayout.LayoutParams(0, -2, 1)
    labelParams.leftMargin = dp(10)
    row.addView(label, labelParams)

    local fileName = TextView(activity)
    fileName.setText(item.getName())
    fileName.setTextSize(13.5)
    fileName.setTextColor(INK)
    label.addView(fileName)

    local meta = TextView(activity)
    if item.isDirectory() then
      meta.setText("文件夹")
    else
      meta.setText(humanSize(item.length()))
    end
    meta.setTextSize(11.5)
    meta.setTextColor(MUTED)
    label.addView(meta)

    row.setOnClickListener(View.OnClickListener{
      onClick = function()
        if item.isDirectory() then
          currentDir = item.getAbsolutePath()
          buildDirPage()
        else
          showFileMenu(item.getAbsolutePath(), false)
        end
      end
    })
    row.setOnLongClickListener(View.OnLongClickListener{
      onLongClick = function()
        showFileMenu(item.getAbsolutePath(), item.isDirectory())
        return true
      end
    })
  end

  return scroll
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
