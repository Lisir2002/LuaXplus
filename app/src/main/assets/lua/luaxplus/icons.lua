-- LuaX 自绘图标：统一把 VectorDrawable 着色后放进页面。
--
-- 设计约束：
-- 1. 图标源稿在 design/icons，Android 资源由 tools/icons/build_icons.py 生成；
-- 2. 运行时只用 setColorFilter 着色，不复制多套彩色资源；
-- 3. 默认根据背景亮度选择深墨或白色，因此同一图标能适配浅色、深色和彩色底；
-- 4. 没有找到资源时退回字形，保证旧工程和裁剪包不会因为缺图标直接报错。

require "import"
import "android.widget.*"
import "android.view.*"
import "android.graphics.*"
import "android.graphics.drawable.*"

local M = {}

local DEFAULT_INK = 0xFF1C2B3A
local DEFAULT_LIGHT = 0xFFFFFFFF
local DEFAULT_BG = 0xFFF2ECE0

local function dp(value)
  local density = 1
  pcall(function()
    density = activity.getResources().getDisplayMetrics().density
  end)
  return math.floor(value * density + 0.5)
end

local function parseColor(value)
  if type(value) == "number" then
    return value
  end
  local text = tostring(value or ""):gsub("#", "")
  local number = tonumber(text, 16)
  if not number then
    return DEFAULT_INK
  end
  if #text == 6 then
    return 0xFF000000 | number
  end
  if #text == 8 then
    return number
  end
  return DEFAULT_INK
end

local function resourceNames()
  return {
    ["menu"] = "ic_luax_menu",
    ["close"] = "ic_luax_close",
    ["add"] = "ic_luax_add",
    ["edit"] = "ic_luax_edit",
    ["manual"] = "ic_luax_manual",
    ["code"] = "ic_luax_code",
    ["info"] = "ic_luax_info",
    ["settings"] = "ic_luax_settings",
    ["chevron-right"] = "ic_luax_chevron_right",
    ["chevron-left"] = "ic_luax_chevron_left",
    ["undo"] = "ic_luax_undo",
    ["redo"] = "ic_luax_redo",
    ["more"] = "ic_luax_more",
    ["search"] = "ic_luax_search",
    ["example"] = "ic_luax_example",
    ["log"] = "ic_luax_log",
    ["run"] = "ic_luax_run",
    ["package"] = "ic_luax_package",
    ["shield"] = "ic_luax_shield",
    ["home"] = "ic_luax_home",
    ["mail"] = "ic_luax_mail",
    ["check"] = "ic_luax_check",
    ["folder"] = "ic_luax_folder",
    ["save"] = "ic_luax_save",
    ["wrap"] = "ic_luax_wrap",
    ["empty"] = "ic_luax_empty",
    ["file"] = "ic_luax_file",
    ["radio"] = "ic_luax_radio",
    ["radio-checked"] = "ic_luax_radio_checked",
  }
end

local NAMES = resourceNames()
local idCache = {}

function M.has(name)
  if not name or type(name) ~= "string" then
    return false
  end
  return NAMES[name] ~= nil
end

function M.drawable(name)
  if type(name) ~= "string" then
    return nil
  end
  if idCache[name] then
    return idCache[name]
  end
  local resource = NAMES[name]
  if not resource then
    return nil
  end
  local id = 0
  pcall(function()
    id = activity.getResources().getIdentifier(resource, "drawable", activity.getPackageName())
  end)
  if id == 0 then
    return nil
  end
  idCache[name] = id
  return id
end

-- 背景亮度决定图标该用深色还是白色，避免图标落在深色/彩色底上失去对比。
function M.contrast(background)
  local color = parseColor(background or DEFAULT_LIGHT)
  local alpha = (color >> 24) & 0xFF
  if alpha == 0 then
    return DEFAULT_INK
  end
  local r = (color >> 16) & 0xFF
  local g = (color >> 8) & 0xFF
  local b = color & 0xFF
  local luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
  if luminance > 0.62 then
    return DEFAULT_INK
  end
  return DEFAULT_LIGHT
end

function M.tint(view, color)
  if not view then
    return view
  end
  local value = parseColor(color)
  local ok = pcall(function()
    view.setColorFilter(value)
  end)
  if not ok then
    pcall(function()
      view.setColorFilter(PorterDuffColorFilter(value, PorterDuff.Mode.SRC_IN))
    end)
  end
  return view
end

-- Drawable 不是 View：VectorDrawable 只接受 ColorFilter 对象，
-- 不能像 ImageView 一样直接传颜色整数，否则 LuaJava 会报 Invalid method call。
function M.tintDrawable(drawable, color)
  if not drawable then
    return drawable
  end
  pcall(function()
    drawable.setColorFilter(PorterDuffColorFilter(parseColor(color), PorterDuff.Mode.SRC_IN))
  end)
  return drawable
end

local function fallbackGlyph(name, spec, color)
  local glyphs = {
    ["menu"] = "≡", ["close"] = "✕", ["add"] = "＋", ["edit"] = "✎",
    ["manual"] = "册", ["code"] = "‹›", ["info"] = "i", ["settings"] = "⚙",
    ["chevron-right"] = "›", ["chevron-left"] = "‹", ["undo"] = "↶",
    ["redo"] = "↷", ["more"] = "⋯", ["search"] = "⌕", ["example"] = "✦",
    ["log"] = "志", ["run"] = "▶", ["package"] = "包", ["shield"] = "盾",
    ["home"] = "⌂", ["mail"] = "✉", ["check"] = "✓", ["folder"] = "▱",
    ["save"] = "存", ["wrap"] = "↵", ["empty"] = "□", ["file"] = "文",
  }
  local text = spec.glyph or glyphs[name] or "•"
  local view = TextView(activity)
  view.setText(text)
  view.setTextSize(spec.glyphSize or 17)
  view.setTextColor(color or DEFAULT_INK)
  view.setGravity(Gravity.CENTER)
  view.setTypeface(Typeface.DEFAULT_BOLD)
  return view
end

-- 生成一个已着色的图标。size 单位为 dp，color 未传时按 background 自动取对比色。
function M.view(name, spec)
  spec = spec or {}
  local size = spec.size or 22
  local background = spec.background or spec.bg
  local color = spec.color or (background and M.contrast(background) or DEFAULT_INK)
  local id = M.drawable(name)
  if not id then
    local view = fallbackGlyph(name, spec, color)
    view.setLayoutParams(LinearLayout.LayoutParams(dp(size), dp(size)))
    return view
  end
  local image = ImageView(activity)
  image.setImageResource(id)
  image.setScaleType(ImageView.ScaleType.CENTER_INSIDE)
  image.setAdjustViewBounds(false)
  image.setColorFilter(parseColor(color))
  if spec.alpha then
    image.setAlpha(spec.alpha)
  end
  local params = spec.layoutParams or LinearLayout.LayoutParams(dp(size), dp(size))
  image.setLayoutParams(params)
  if spec.contentDescription then
    image.setContentDescription(spec.contentDescription)
  end
  return image
end

local function roundBackground(fill, radius, strokeColor)
  local drawable = GradientDrawable()
  drawable.setShape(GradientDrawable.RECTANGLE)
  drawable.setColor(parseColor(fill or DEFAULT_BG))
  drawable.setCornerRadius(dp(radius or 10))
  if strokeColor then
    drawable.setStroke(dp(1), parseColor(strokeColor))
  end
  return drawable
end

-- 带底色的图标徽章；适合侧栏入口、工具按钮、空状态。
function M.chip(name, spec)
  spec = spec or {}
  local size = spec.size or 32
  local radius = spec.radius or 10
  local background = spec.background or spec.bg or DEFAULT_BG
  local iconColor = spec.color or M.contrast(background)
  local frame = FrameLayout(activity)
  frame.setBackground(roundBackground(background, radius, spec.stroke))
  local icon = M.view(name, {
    size = spec.iconSize or math.max(14, size - 12),
    color = iconColor,
    glyph = spec.glyph,
    glyphSize = spec.glyphSize,
  })
  local params = FrameLayout.LayoutParams(-2, -2)
  params.gravity = Gravity.CENTER
  frame.addView(icon, params)
  local extent = dp(size)
  frame.setMinimumWidth(extent)
  frame.setMinimumHeight(extent)
  frame.setLayoutParams(spec.layoutParams or LinearLayout.LayoutParams(extent, extent))
  if spec.onClick then
    frame.setOnClickListener(View.OnClickListener{ onClick = spec.onClick })
  end
  if spec.alpha then
    frame.setAlpha(spec.alpha)
  end
  return frame
end

-- 图标 + 文字的横向按钮；文字为空时退化为纯图标按钮。
function M.button(name, text, spec)
  spec = spec or {}
  local palette = spec
  local row = LinearLayout(activity)
  row.setOrientation(LinearLayout.HORIZONTAL)
  row.setGravity(Gravity.CENTER_VERTICAL)
  row.setPadding(dp(spec.paddingLeft or 10), dp(spec.paddingY or 7),
                 dp(spec.paddingRight or 12), dp(spec.paddingY or 7))
  row.setBackground(roundBackground(spec.background or 0x00000000,
                                    spec.radius or 10, spec.stroke))
  local color = spec.color or spec.textColor or DEFAULT_INK
  local icon = M.view(name, {
    size = spec.iconSize or 17,
    color = color,
    glyph = spec.glyph,
    glyphSize = spec.glyphSize,
  })
  row.addView(icon, LinearLayout.LayoutParams(dp(spec.iconSize or 17), dp(spec.iconSize or 17)))
  if text and text ~= "" then
    local label = TextView(activity)
    label.setText(text)
    label.setTextSize(spec.textSize or 13)
    label.setTextColor(color)
    if spec.bold then
      label.setTypeface(Typeface.DEFAULT_BOLD)
    end
    label.setSingleLine(true)
    local params = LinearLayout.LayoutParams(-2, -2)
    params.leftMargin = dp(spec.gap or 5)
    row.addView(label, params)
  end
  if spec.onClick then
    row.setOnClickListener(View.OnClickListener{ onClick = spec.onClick })
  end
  if spec.enabled == false then
    row.setAlpha(0.45)
    row.setEnabled(false)
  end
  return row
end

return M
