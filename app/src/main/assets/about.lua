require "import"
import "android.app.*"
import "android.os.*"
import "android.widget.*"
import "android.view.*"
import "android.graphics.Typeface"
import "android.graphics.drawable.GradientDrawable"
import "autotheme"

activity.setTheme(autotheme())
activity.setTitle("关于")

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
local icons = require "luaxplus.icons"
local C = theme.colors
local BG = C.paper
local CARD = C.card
local INK = C.ink
local MUTED = C.muted
local LINE = C.line
local ACCENT = C.accent

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

local function label(text, size, color, bold)
  local view = TextView(activity)
  view.setText(text)
  view.setTextSize(size)
  view.setTextColor(color)
  if bold then
    view.setTypeface(Typeface.DEFAULT_BOLD)
  end
  return view
end

local function section(title, body)
  local box = LinearLayout(activity)
  box.setOrientation(LinearLayout.VERTICAL)
  box.setPadding(dp(16), dp(14), dp(16), dp(14))
  box.setBackground(rounded(CARD, LINE, 14))

  local heading = label(title, 14, INK, true)
  box.addView(heading)

  local desc = label(body, 12, MUTED)
  desc.setPadding(0, dp(7), 0, 0)
  desc.setLineSpacing(dp(3), 1)
  box.addView(desc)
  return box
end

local root = LinearLayout(activity)
root.setOrientation(LinearLayout.VERTICAL)
root.setBackgroundColor(BG)
root.setFitsSystemWindows(true)

local header = LinearLayout(activity)
header.setOrientation(LinearLayout.HORIZONTAL)
header.setGravity(Gravity.CENTER_VERTICAL)
header.setPadding(dp(10), dp(14), dp(16), dp(8))
root.addView(header, LinearLayout.LayoutParams(-1, -2))

local back = icons.view("chevron-left", { size = 20, color = INK })
back.setOnClickListener(View.OnClickListener{
  onClick = function()
    activity.finish()
  end
})
header.addView(back, LinearLayout.LayoutParams(dp(38), dp(44)))

local titleBox = LinearLayout(activity)
titleBox.setOrientation(LinearLayout.VERTICAL)
header.addView(titleBox, LinearLayout.LayoutParams(0, -2, 1))

titleBox.addView(label("关于", 23, INK, true))
local sub = label("Mini-LuaXPLUS · 移动端 Lua 开发工作台", 11.5, MUTED)
sub.setPadding(0, dp(2), 0, 0)
titleBox.addView(sub)

local scroll = ScrollView(activity)
scroll.setFillViewport(true)
local content = LinearLayout(activity)
content.setOrientation(LinearLayout.VERTICAL)
content.setPadding(dp(16), dp(4), dp(16), dp(28))
scroll.addView(content, LinearLayout.LayoutParams(-1, -2))
root.addView(scroll, LinearLayout.LayoutParams(-1, 0, 1))

local versionName = ""
local packageName = tostring(activity.getPackageName())
pcall(function()
  local info = activity.getPackageManager().getPackageInfo(packageName, 0)
  versionName = tostring(info.versionName)
end)

local hero = LinearLayout(activity)
hero.setOrientation(LinearLayout.VERTICAL)
hero.setGravity(Gravity.CENTER)
hero.setPadding(dp(20), dp(22), dp(20), dp(22))
hero.setBackground(rounded(CARD, LINE, 18))
content.addView(hero, LinearLayout.LayoutParams(-1, -2))

hero.addView(label("Mini-LuaXPLUS", 21, INK, true))
local version = label("版本 " .. (versionName ~= "" and versionName or "1.0.0"), 12, MUTED)
version.setPadding(0, dp(6), 0, 0)
hero.addView(version)
local tagline = label("写脚本、管工程、直接打包成 APK", 12, MUTED)
tagline.setGravity(Gravity.CENTER)
tagline.setPadding(0, dp(6), 0, 0)
hero.addView(tagline)

local function addSection(title, body)
  local card = section(title, body)
  local params = LinearLayout.LayoutParams(-1, -2)
  params.topMargin = dp(12)
  content.addView(card, params)
end

addSection("当前版本", "包名：" .. packageName .. "\n版本：" .. (versionName ~= "" and versionName or "1.0.0"))
addSection("这个应用做什么", "把 Lua 工程放在 LuaXPlus/project，在应用里浏览、编辑、运行和打包；官方示例与自建工程分开管理。")
addSection("关于页面", "当前是独立占位页面，后续补充更新日志、开源许可、问题反馈和开发者信息。")

local footer = label("Mini-LuaXPLUS · 本地优先的移动开发工具", 11, MUTED)
footer.setGravity(Gravity.CENTER)
footer.setPadding(0, dp(24), 0, 0)
content.addView(footer, LinearLayout.LayoutParams(-1, -2))

theme.apply(activity, { background = BG, root = root, dark = false })
activity.setContentView(root)
