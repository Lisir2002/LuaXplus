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

-- 官方示例列表：工程落在 LuaXPlus/examples，首次打开时从内置资产铺设。
-- 示例工程和普通工程一样，可以进入详情、编辑文件、运行和打包。

activity.setTheme(autotheme())
activity.setTitle("官方示例")

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

local theme = require "luaxplus.theme"
local C = theme.colors
local PAPER = C.paper
local CARD = C.card
local INK = C.ink
local MUTED = C.muted
local LINE = C.line
local ACCENT = C.accent
local ACCENT_DEEP = C.accentDeep
local ACCENT_WASH = C.accentWash
local ACCENT_LINE = C.accentLine
local PAPER_SOFT = C.paperSoft
local MUTED_SOFT = C.mutedSoft
local MUTED_LIGHT = C.mutedLight

local dp = function(n)
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

local examplesRoot = activity.getLuaExtDir("examples")
local sourceRoot = activity.getFilesDir().getAbsolutePath() .. "/examples"

local appVersion = ""
pcall(function()
  local info = activity.getPackageManager().getPackageInfo(activity.getPackageName(), 0)
  appVersion = tostring(info.versionName)
end)

local function copyFile(source, target)
  local input = io.open(source, "rb")
  if not input then
    return false
  end
  local data = input:read("*a")
  input:close()
  local output = io.open(target, "wb")
  if not output then
    return false
  end
  output:write(data)
  output:close()
  return true
end

local function copyTree(source, target, force)
  local sourceFile = File(source)
  if not sourceFile.exists() then
    return
  end
  if sourceFile.isDirectory() then
    File(target).mkdirs()
    local children = sourceFile.listFiles()
    if not children then
      return
    end
    for index = 0, #children - 1 do
      local child = children[index]
      local name = child.getName()
      if name ~= ".bundle" and name ~= ".DS_Store" then
        copyTree(child.getAbsolutePath(), target .. "/" .. name, force)
      end
    end
    return
  end
  if not force and File(target).exists() then
    return
  end
  local parent = File(target).getParentFile()
  if parent and not parent.exists() then
    parent.mkdirs()
  end
  copyFile(source, target)
end

local function readMarker()
  local file = io.open(examplesRoot .. "/.bundle", "r")
  if not file then
    return ""
  end
  local value = file:read("*a") or ""
  file:close()
  return value
end

local function writeMarker()
  local file = io.open(examplesRoot .. "/.bundle", "w")
  if file then
    file:write(appVersion)
    file:close()
  end
end

local function hasExample()
  local children = File(examplesRoot).listFiles()
  if not children then
    return false
  end
  for index = 0, #children - 1 do
    local child = children[index]
    if child.isDirectory() and File(child.getAbsolutePath() .. "/init.lua").isFile() then
      return true
    end
  end
  return false
end

local function removeTree(path)
  local file = File(path)
  local children = file.listFiles()
  if children then
    for index = 0, #children - 1 do
      removeTree(children[index].getAbsolutePath())
    end
  end
  pcall(function()
    file.delete()
  end)
end

local function removeObsoleteExamples()
  -- 早期拆分的快速示例已并入完整示例，旧安装留下的目录需要清掉
  for _, name in ipairs({ "luax-ui-quick" }) do
    local path = examplesRoot .. "/" .. name
    if File(path).exists() then
      removeTree(path)
    end
  end
end

local function ensureExamples(force)
  removeObsoleteExamples()
  local changed = force or readMarker() ~= appVersion or not hasExample()
  if not changed then
    return true
  end
  if not File(sourceRoot).isDirectory() then
    toast("内置示例资产缺失，请重新安装新版编辑器")
    return false
  end
  File(examplesRoot).mkdirs()
  copyTree(sourceRoot, examplesRoot, true)
  writeMarker()
  return true
end

local function readInfo(dir)
  local info = {}
  local ok = pcall(function()
    local chunk = loadfile(dir .. "/init.lua", "bt", info)
    if chunk then
      chunk()
    end
  end)
  if not ok or not info.appname then
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
    for index = 0, #list - 1 do
      local item = list[index]
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

-- ===== 页面 =====
local root = LinearLayout(activity)
root.setOrientation(LinearLayout.VERTICAL)
root.setBackgroundColor(PAPER)
root.setFitsSystemWindows(true)

local header = LinearLayout(activity)
header.setOrientation(LinearLayout.HORIZONTAL)
header.setGravity(Gravity.CENTER_VERTICAL)
header.setPadding(dp(10), dp(14), dp(14), dp(8))

local back = TextView(activity)
back.setText("‹")
back.setTextSize(28)
back.setTextColor(INK)
back.setGravity(Gravity.CENTER)
back.setPadding(0, 0, 0, 0)
header.addView(back, LinearLayout.LayoutParams(dp(36), dp(44)))
back.setOnClickListener(View.OnClickListener{
  onClick = function()
    activity.finish()
  end
})

local titleBox = LinearLayout(activity)
titleBox.setOrientation(LinearLayout.VERTICAL)
header.addView(titleBox, LinearLayout.LayoutParams(0, -2, 1))

local title = TextView(activity)
title.setText("官方示例")
title.setTextSize(23)
title.setTypeface(Typeface.DEFAULT_BOLD)
title.setTextColor(INK)
titleBox.addView(title)

local subtitle = TextView(activity)
subtitle.setText("内置工程，可直接编辑、运行和打包")
subtitle.setTextSize(11.5)
subtitle.setTextColor(MUTED)
subtitle.setPadding(0, dp(2), 0, 0)
titleBox.addView(subtitle)

local restore = TextView(activity)
restore.setText("恢复")
restore.setTextSize(12)
restore.setTextColor(ACCENT_DEEP)
restore.setGravity(Gravity.CENTER)
restore.setPadding(dp(11), dp(6), dp(11), dp(6))
restore.setBackground(rounded(ACCENT_WASH, ACCENT_LINE, 10))
header.addView(restore)

root.addView(header, LinearLayout.LayoutParams(-1, -2))

local summary = TextView(activity)
summary.setTextSize(12)
summary.setTextColor(MUTED)
summary.setPadding(dp(20), 0, dp(18), dp(6))
summary.setText("官方示例固定在 LuaXPlus/examples，与自建工程的 LuaXPlus/project 完全分开。")
root.addView(summary, LinearLayout.LayoutParams(-1, -2))

local scroll = ScrollView(activity)
scroll.setFillViewport(true)
local list = LinearLayout(activity)
list.setOrientation(LinearLayout.VERTICAL)
list.setPadding(dp(16), dp(4), dp(16), dp(24))
scroll.addView(list, LinearLayout.LayoutParams(-1, -2))
root.addView(scroll, LinearLayout.LayoutParams(-1, 0, 1))

theme.apply(activity, { background = PAPER, root = root, dark = false })
activity.setContentView(root)

-- ===== 卡片 =====
local function openProject(info)
  activity.newActivity("projectpage", {info.path})
end

local function restoreOne(info)
  local bundle = sourceRoot .. "/" .. (info.dirName or "")
  if not File(bundle).isDirectory() then
    toast("没有找到这个示例的内置副本")
    return
  end
  MaterialAlertDialogBuilder(activity)
    .setTitle("恢复示例")
    .setMessage("「" .. info.appname .. "」里的改动会被内置版本覆盖，确定恢复？")
    .setNegativeButton("取消", nil)
    .setPositiveButton("恢复", function()
      copyTree(bundle, info.path, true)
      toast("已恢复「" .. info.appname .. "」")
      refresh()
    end)
    .show()
end

local function showMenu(info)
  local options = {"恢复此示例", "打开所在目录"}
  MaterialAlertDialogBuilder(activity)
    .setTitle(info.appname)
    .setItems(options, function(_, which)
      if which == 0 then
        restoreOne(info)
      else
        toast("目录：" .. info.path)
      end
    end)
    .show()
end

local function buildIcon(info)
  local iconFile = File(info.path .. "/icon.png")
  if iconFile.isFile() then
    local icon = ImageView(activity)
    icon.setImageBitmap(loadbitmap(iconFile.getAbsolutePath()))
    icon.setScaleType(ImageView.ScaleType.CENTER_CROP)
    icon.setBackground(rounded(PAPER_SOFT, nil, 12))
    return icon
  end

  local glyph = TextView(activity)
  glyph.setText("UI")
  glyph.setTextSize(15)
  glyph.setTypeface(Typeface.DEFAULT_BOLD)
  glyph.setTextColor(C.onAccent)
  glyph.setGravity(Gravity.CENTER)
  glyph.setBackground(rounded(ACCENT, nil, 12))
  return glyph
end

local function buildCard(info)
  local card = LinearLayout(activity)
  card.setOrientation(LinearLayout.HORIZONTAL)
  card.setGravity(Gravity.CENTER_VERTICAL)
  card.setPadding(dp(14), dp(13), dp(14), dp(13))
  card.setBackground(rounded(CARD, LINE, 16))

  card.addView(buildIcon(info), LinearLayout.LayoutParams(dp(50), dp(50)))

  local texts = LinearLayout(activity)
  texts.setOrientation(LinearLayout.VERTICAL)
  local params = LinearLayout.LayoutParams(0, -2, 1)
  params.leftMargin = dp(12)
  card.addView(texts, params)

  local nameRow = LinearLayout(activity)
  nameRow.setOrientation(LinearLayout.HORIZONTAL)
  nameRow.setGravity(Gravity.CENTER_VERTICAL)
  texts.addView(nameRow)

  local name = TextView(activity)
  name.setText(info.appname .. "  v" .. (info.appver or "1.0"))
  name.setTextSize(16)
  name.setTypeface(Typeface.DEFAULT_BOLD)
  name.setTextColor(INK)
  nameRow.addView(name)

  local badge = TextView(activity)
  badge.setText("官方")
  badge.setTextSize(10)
  badge.setTextColor(ACCENT_DEEP)
  badge.setGravity(Gravity.CENTER)
  badge.setPadding(dp(6), dp(2), dp(6), dp(2))
  badge.setBackground(rounded(ACCENT_WASH, nil, 8))
  local badgeParams = LinearLayout.LayoutParams(-2, -2)
  badgeParams.leftMargin = dp(7)
  nameRow.addView(badge, badgeParams)

  local sub = TextView(activity)
  sub.setText((info.packagename or "未设置包名") .. " · " .. humanSize(dirSize(info.path)))
  sub.setTextSize(12)
  sub.setTextColor(MUTED)
  sub.setPadding(0, dp(3), 0, 0)
  texts.addView(sub)

  local desc = TextView(activity)
  desc.setText((info.description and info.description ~= "") and info.description or "官方示例工程")
  desc.setTextSize(12.5)
  desc.setTextColor(MUTED_SOFT)
  desc.setMaxLines(2)
  desc.setPadding(0, dp(4), 0, 0)
  texts.addView(desc)

  local arrow = TextView(activity)
  arrow.setText("›")
  arrow.setTextSize(18)
  arrow.setTextColor(MUTED_LIGHT)
  card.addView(arrow)

  card.setOnClickListener(View.OnClickListener{
    onClick = function()
      openProject(info)
    end
  })
  card.setOnLongClickListener(View.OnLongClickListener{
    onLongClick = function()
      showMenu(info)
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
  box.setPadding(dp(24), dp(56), dp(24), dp(40))

  local glyph = TextView(activity)
  glyph.setText("UI")
  glyph.setTextSize(28)
  glyph.setTypeface(Typeface.DEFAULT_BOLD)
  glyph.setTextColor(ACCENT)
  glyph.setGravity(Gravity.CENTER)
  box.addView(glyph, LinearLayout.LayoutParams(dp(64), dp(64)))

  local text = TextView(activity)
  text.setText("官方示例还没铺好")
  text.setTextSize(16)
  text.setTextColor(INK)
  text.setGravity(Gravity.CENTER)
  text.setPadding(0, dp(14), 0, dp(4))
  box.addView(text)

  local hint = TextView(activity)
  hint.setText("点右上角「恢复」重新铺设内置示例")
  hint.setTextSize(12.5)
  hint.setTextColor(MUTED)
  hint.setGravity(Gravity.CENTER)
  box.addView(hint)
  return box
end

-- ===== 列表 =====
function refresh()
  list.removeAllViews()
  local dirs = File(examplesRoot).listFiles()
  local items = {}
  if dirs then
    for index = 0, #dirs - 1 do
      local item = dirs[index]
      if item.isDirectory() then
        local info = readInfo(item.getAbsolutePath())
        if info and info.official then
          info.dirName = item.getName()
          table.insert(items, info)
        end
      end
    end
  end
  table.sort(items, function(a, b)
    return (a.appname or "") < (b.appname or "")
  end)

  if #items == 0 then
    list.addView(buildEmpty())
    summary.setText("共 0 个官方示例")
    return
  end

  summary.setText("共 " .. #items .. " 个官方示例 · 与自建工程隔离，改动保存在 " .. examplesRoot)
  for index = 1, #items do
    list.addView(buildCard(items[index]))
  end
end

restore.setOnClickListener(View.OnClickListener{
  onClick = function()
    MaterialAlertDialogBuilder(activity)
      .setTitle("恢复全部示例")
      .setMessage("所有官方示例的改动会被内置版本覆盖，确定继续？")
      .setNegativeButton("取消", nil)
      .setPositiveButton("恢复", function()
        if ensureExamples(true) then
          toast("官方示例已恢复")
          refresh()
        end
      end)
      .show()
  end
})

ensureExamples(false)
refresh()
