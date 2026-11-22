require "import"
import "android.app.*"
import "android.os.*"
import "android.widget.*"
import "android.view.*"
import "android.graphics.Typeface"
import "android.graphics.drawable.GradientDrawable"
import "autotheme"

activity.setTheme(autotheme())
activity.setTitle("设置")

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

local root = LinearLayout(activity)
root.setOrientation(LinearLayout.VERTICAL)
root.setBackgroundColor(BG)
root.setFitsSystemWindows(true)

local header = LinearLayout(activity)
header.setOrientation(LinearLayout.HORIZONTAL)
header.setGravity(Gravity.CENTER_VERTICAL)
header.setPadding(dp(10), dp(14), dp(16), dp(8))
root.addView(header, LinearLayout.LayoutParams(-1, -2))

local back = label("‹", 28, INK)
back.setGravity(Gravity.CENTER)
back.setOnClickListener(View.OnClickListener{
  onClick = function()
    activity.finish()
  end
})
header.addView(back, LinearLayout.LayoutParams(dp(38), dp(44)))

local titleBox = LinearLayout(activity)
titleBox.setOrientation(LinearLayout.VERTICAL)
header.addView(titleBox, LinearLayout.LayoutParams(0, -2, 1))

titleBox.addView(label("设置", 23, INK, true))
local sub = label("偏好与行为配置", 11.5, MUTED)
sub.setPadding(0, dp(2), 0, 0)
titleBox.addView(sub)

local scroll = ScrollView(activity)
scroll.setFillViewport(true)
local content = LinearLayout(activity)
content.setOrientation(LinearLayout.VERTICAL)
content.setPadding(dp(16), dp(4), dp(16), dp(28))
scroll.addView(content, LinearLayout.LayoutParams(-1, -2))
root.addView(scroll, LinearLayout.LayoutParams(-1, 0, 1))

local function row(title, detail)
  local box = LinearLayout(activity)
  box.setOrientation(LinearLayout.VERTICAL)
  box.setPadding(dp(16), dp(14), dp(16), dp(14))
  box.addView(label(title, 14, INK, true))

  local desc = label(detail, 12, MUTED)
  desc.setPadding(0, dp(5), 0, 0)
  box.addView(desc)
  return box
end

local intro = TextView(activity)
intro.setText("外观、编辑器、存储与同步仍为占位；权限管理已接入独立页面。")
intro.setTextSize(12)
intro.setTextColor(MUTED)
intro.setPadding(dp(8), dp(8), dp(8), dp(4))
content.addView(intro, LinearLayout.LayoutParams(-1, -2))

local group = LinearLayout(activity)
group.setOrientation(LinearLayout.VERTICAL)
group.setBackground(rounded(CARD, LINE, 14))
content.addView(group, LinearLayout.LayoutParams(-1, -2))

local items = {
  { "外观", "浅色 / 深色主题、强调色" },
  { "编辑器", "字号、自动保存、缩进与符号条" },
  { "存储与同步", "项目目录、外部删除同步、备份与恢复" },
  { "权限管理", "存储、网络与全部敏感权限", "permissioncenter" }
}

for index = 1, #items do
  local item = items[index]
  local itemView = row(item[1], item[2])
  group.addView(itemView)
  if item[3] then
    itemView.setOnClickListener(View.OnClickListener{
      onClick = function()
        local ok, err = pcall(function()
          activity.newActivity(item[3])
        end)
        if not ok then
          Toast.makeText(activity, "权限管理页启动失败：" .. tostring(err), Toast.LENGTH_SHORT).show()
        end
      end
    })
  end
  if index < #items then
    local line = View(activity)
    line.setBackgroundColor(LINE)
    local lineParams = LinearLayout.LayoutParams(-1, dp(1))
    lineParams.leftMargin = dp(16)
    group.addView(line, lineParams)
  end
end

local note = label("权限管理已接入；其余设置项仍在逐步接入。", 11, MUTED)
note.setGravity(Gravity.CENTER)
note.setPadding(0, dp(18), 0, 0)
content.addView(note, LinearLayout.LayoutParams(-1, -2))

theme.apply(activity, { background = BG, root = root, dark = false })
activity.setContentView(root)
