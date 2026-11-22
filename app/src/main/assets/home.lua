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

-- 首页：应用（项目）列表
-- 数据来源：外部目录 project 下的工程文件夹，每个文件夹带 init.lua 描述信息

activity.setTheme(autotheme())
activity.setTitle("应用")

local PAPER = 0xfff7f1e6
local CARD = 0xfffdf8
local INK = 0xff1c2b3a
local MUTED = 0xff5f6f7c
local ACCENT = 0xff0f9e97
local LINE = 0xffe6dbc8

local projectRoot = activity.getLuaExtDir("project")

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
  local file = io.open(info.path .. "/init.lua", "w")
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

local root = LinearLayout(activity)
root.setOrientation(LinearLayout.VERTICAL)
root.setBackgroundColor(PAPER)
root.setFitsSystemWindows(true)

-- 顶部标题区
local header = LinearLayout(activity)
header.setOrientation(LinearLayout.HORIZONTAL)
header.setGravity(Gravity.CENTER_VERTICAL)
header.setPadding(dp(18), dp(16), dp(14), dp(6))

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

activity.setContentView(root)

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
      toast("已删除「" .. info.appname .. "」")
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
      if dirs[i].isDirectory() then
        local info = readInfo(dirs[i].getAbsolutePath())
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

refresh()
