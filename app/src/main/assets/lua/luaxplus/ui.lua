-- LuaX-UI：Mini-LuaXPLUS 自带的 iOS 风格原生组件库
--
-- 设计原则：
-- 1. 纯增量模块，不修改 import、luajava、LuaActivity 或任何原生写法；
-- 2. 所有组件都只是普通 Android View 的封装，页面仍可直接 addView、setContentView；
-- 3. 视觉语言参考 iOS 的系统分组、留白、圆角、细分割线与系统色，不复制任何第三方皮肤。
--
-- 用法：local ui = require "luaxplus.ui"

require "import"
import "android.widget.*"
import "android.view.*"
import "android.graphics.*"
import "android.graphics.drawable.*"
import "android.content.res.ColorStateList"
import "android.text.*"
import "android.text.style.*"
import "android.app.*"
import "android.os.*"
import "android.util.TypedValue"
import "android.animation.*"
import "android.view.animation.*"

pcall(function()
  import "loadbitmap"
end)

local icons = require "luaxplus.icons"

local M = {}

-- ===== 设计令牌 =====
-- 令牌是组件库唯一的视觉来源：颜色、间距、圆角、字体、控件尺寸和动效都从这里读取。
-- Lua 侧使用点号：ui.tokens.color.label、ui.tokens.spacing[16]、ui.tokens.type.body.size。
-- HTML 侧使用同名 CSS 变量：--lx-color-label、--lx-spacing-16、--lx-type-body-size。

local function parseColor(value)
  if type(value) == "number" then
    return value
  end
  local text = tostring(value or ""):gsub("#", "")
  local number = tonumber(text, 16)
  if not number then
    return 0xFF000000
  end
  if #text == 6 then
    return 0xFF000000 | number
  end
  if #text == 8 then
    return number
  end
  return 0xFF000000
end

local function clone(value)
  if type(value) ~= "table" then
    return value
  end
  local result = {}
  for key, item in pairs(value) do
    result[key] = clone(item)
  end
  return result
end

local function merge(base, patch)
  local result = clone(base or {})
  for key, value in pairs(patch or {}) do
    if type(value) == "table" and type(result[key]) == "table" then
      result[key] = merge(result[key], value)
    else
      result[key] = clone(value)
    end
  end
  return result
end

local function normalizeColors(theme)
  for key, value in pairs(theme.color or {}) do
    theme.color[key] = parseColor(value)
  end
  return theme
end

local BASE = {
  spacing = {
    [0] = 0,
    [1] = 1,
    [2] = 2,
    [4] = 4,
    [6] = 6,
    [7] = 7,
    [8] = 8,
    [10] = 10,
    [11] = 11,
    [12] = 12,
    [14] = 14,
    [16] = 16,
    [18] = 18,
    [19] = 19,
    [22] = 22,
    [24] = 24,
    [26] = 26,
    [28] = 28,
    [32] = 32,
    [36] = 36,
    [38] = 38,
    [44] = 44,
    [46] = 46,
    [52] = 52,
    [57] = 57,
    [72] = 72,
    page = 16,
    card = 16,
    section = 24,
    row = 12,
    gap = 8,
    tight = 6,
    buttonX = 14,
    buttonY = 12,
    navX = 12,
    navY = 7,
    labelX = 4,
    labelY = 2,
    helperX = 4,
    helperTop = 4,
    checkboxX = 4,
    checkboxY = 6,
    checkboxGap = 8,
    tabTop = 4,
    tabBottom = 2,
    tabGap = 2,
    kvX = 16,
    kvY = 10,
    motionY = 14,
  },
  radius = {
    [0] = 0,
    [7] = 7,
    [8] = 8,
    [9] = 9,
    [10] = 10,
    [12] = 12,
    [14] = 14,
    [16] = 16,
    [18] = 18,
    [20] = 20,
    [22] = 22,
    [26] = 26,
    [999] = 999,
    card = 12,
    button = 12,
    input = 12,
    chip = 16,
    sheet = 14,
    dialog = 14,
    search = 10,
    segment = 9,
    segmentItem = 7,
    badge = 8,
    iconBadge = 7,
    banner = 12,
    toast = 18,
    avatar = 20,
    fab = 26,
    nav = 22,
    check = 12,
    skeleton = 6,
    glyph = 9,
    stepper = 10,
  },
  type = {
    display = { size = 34, weight = 700, lineHeight = 40 },
    title = { size = 29, weight = 600, lineHeight = 34 },
    headline = { size = 23, weight = 600, lineHeight = 28 },
    bodyLarge = { size = 20, weight = 400, lineHeight = 26 },
    body = { size = 17, weight = 400, lineHeight = 22 },
    bodyCompact = { size = 16, weight = 400, lineHeight = 21 },
    callout = { size = 15, weight = 400, lineHeight = 20 },
    subhead = { size = 14, weight = 400, lineHeight = 19 },
    footnote = { size = 13, weight = 400, lineHeight = 18 },
    caption = { size = 11, weight = 400, lineHeight = 15, tracking = 0.04 },
    micro = { size = 10, weight = 400, lineHeight = 14, tracking = 0.02 },
    icon = { size = 20, weight = 400, lineHeight = 24 },
    glyph = { size = 27, weight = 400, lineHeight = 30 },
    stat = { size = 28, weight = 600, lineHeight = 34 },
    action = { size = 22, weight = 400, lineHeight = 27 },
    fab = { size = 26, weight = 400, lineHeight = 31 },
    emptyGlyph = { size = 44, weight = 400, lineHeight = 50 },
  },
  control = {
    buttonHeight = 46,
    inputHeight = 44,
    rowHeight = 44,
    navHeight = 44,
    tabHeight = 45,
    iconBadge = 29,
    fab = 52,
    sheetItem = 57,
    actionHeight = 44,
    searchHeight = 36,
    segment = 28,
    checkMark = 24,
    chipHeight = 32,
    stepper = 38,
    bannerGlyph = 28,
    avatar = 40,
    avatarGroup = 32,
    avatarFontRatio = 2.4,
    statusDot = 8,
    alertWidth = 270,
    hitTarget = 44,
    border = 1,
    hairline = 0.5,
  },
  motion = {
    fast = 90,
    normal = 120,
    slow = 260,
    stagger = 55,
    shimmer = 900,
    staggerItem = 280,
    pressScale = 0.97,
    enterScale = 0.92,
  },
  elevation = {
    card = 0,
    fab = 6,
    sheet = 16,
  },
  opacity = {
    transparent = 0,
    faint = 0.04,
    subtle = 0.08,
    light = 0.12,
    medium = 0.24,
    strong = 0.48,
    heavy = 0.72,
    solid = 0.96,
    disabled = 0.42,
    pressed = 0.7,
    overlay = 0.35,
    scrim = 0.55,
    shimmerLow = 0.28,
    shimmerHigh = 0.72,
  },
}

local LIGHT = normalizeColors({
  color = {
    transparent = "#00000000",
    bg = "#F2F2F7",
    surface = "#FFFFFF",
    surfaceRaised = "#FFFFFF",
    surfacePressed = "#E5E5EA",
    label = "#000000",
    secondary = "#8A8A8E",
    tertiary = "#C7C7CC",
    separator = "#C6C6C8",
    fill = "#E9E9EB",
    accent = "#007AFF",
    accentSoft = "#E5F0FF",
    onAccent = "#FFFFFF",
    success = "#34C759",
    warning = "#FF9500",
    danger = "#FF3B30",
    info = "#5AC8FA",
    purple = "#AF52DE",
    pink = "#FF2D55",
    yellow = "#FFCC00",
    gray = "#8E8E93",
    disabled = "#999999",
    overlay = "#66000000",
    scrim = "#99000000",
    press = "#14000000",
    pressStrong = "#22000000",
    pressOnAccent = "#33FFFFFF",
  },
})

local DARK = normalizeColors({
  color = {
    transparent = "#00000000",
    bg = "#000000",
    surface = "#1C1C1E",
    surfaceRaised = "#2C2C2E",
    surfacePressed = "#3A3A3C",
    label = "#FFFFFF",
    secondary = "#8D8D93",
    tertiary = "#48484A",
    separator = "#38383A",
    fill = "#2C2C2E",
    accent = "#0A84FF",
    accentSoft = "#0A2540",
    onAccent = "#FFFFFF",
    success = "#30D158",
    warning = "#FF9F0A",
    danger = "#FF453A",
    info = "#64D2FF",
    purple = "#BF5AF2",
    pink = "#FF375F",
    yellow = "#FFD60A",
    gray = "#8D8D93",
    disabled = "#666666",
    overlay = "#99000000",
    scrim = "#CC000000",
    press = "#14FFFFFF",
    pressStrong = "#22FFFFFF",
    pressOnAccent = "#33FFFFFF",
  },
})

local function buildTheme(mode, colors)
  local theme = clone(BASE)
  theme.mode = mode
  theme.color = clone(colors.color)
  return theme
end

local THEMES = {
  light = buildTheme("light", LIGHT),
  dark = buildTheme("dark", DARK),
}

M.themes = { light = THEMES.light, dark = THEMES.dark }
M.appearance = "auto"
M.themeName = "auto"
M.tokens = {}

local function syncTable(target, source)
  for key, value in pairs(source) do
    if type(value) == "table" then
      if type(target[key]) ~= "table" then
        target[key] = {}
      end
      syncTable(target[key], value)
    else
      target[key] = value
    end
  end
  for key in pairs(target) do
    if source[key] == nil then
      target[key] = nil
    end
  end
end

local function applyTokens(theme)
  syncTable(M.tokens, theme)
  return M.tokens
end

local function systemDark()
  local current = activity
  if not current then
    return false
  end
  local mode = current.getResources().getConfiguration().uiMode
  return math.floor(mode / 32) % 2 == 1
end

function M.isDark()
  if M.appearance == "dark" then
    return true
  elseif M.appearance == "light" then
    return false
  end
  return systemDark()
end

local function customTheme(name)
  local theme = M.customThemes and M.customThemes[name]
  if not theme then
    return nil
  end
  return theme
end

local function currentTheme()
  if M.themeName == "auto" then
    return M.isDark() and THEMES.dark or THEMES.light
  elseif M.themeName == "light" then
    return THEMES.light
  elseif M.themeName == "dark" then
    return THEMES.dark
  end
  local theme = customTheme(M.themeName)
  if theme then
    return M.isDark() and theme.dark or theme.light
  end
  return M.isDark() and THEMES.dark or THEMES.light
end

local function applyCurrentTheme()
  return applyTokens(currentTheme())
end

applyCurrentTheme()

local C = M.tokens.color
local S = M.tokens.spacing
local R = M.tokens.radius
local TY = M.tokens.type
local K = M.tokens.control
local MO = M.tokens.motion
local EL = M.tokens.elevation
local OP = M.tokens.opacity

-- 所有尺寸、字号、圆角和透明度共用同一套数值解析：
-- 既接受令牌档位（space("card")、radius("button")、textSize="body"），
-- 也接受无级数值（12、"12px"、"12dp"、"12sp"、"12pt"、"35%"）。
local baseDp = dp
if type(baseDp) ~= "function" then
  baseDp = function(number)
    local density = activity and activity.getResources().getDisplayMetrics().density or 1
    return math.floor((number or 0) * density + 0.5)
  end
end

local function numberValue(value, fallback)
  if type(value) == "number" then
    return value
  end
  if type(value) ~= "string" then
    return fallback
  end
  local text = value:gsub("%s+", "")
  local number, unit = text:match("^([%-+]?%d*%.?%d+)([%%%a]*)$")
  number = tonumber(number)
  if not number then
    return fallback
  end
  if unit == "%" then
    return number / 100
  end
  return number
end

local function dimension(value, fallback)
  return numberValue(value, fallback or 0)
end

-- 本地 dp 包一层，既保留原生 dp 的取整行为，也让所有传入 dp 的令牌支持字符串数值。
local function dp(value)
  return baseDp(dimension(value, 0))
end

-- 极细分割线：优先使用控件令牌 control.hairline，至少保证 1 个物理像素。
local function hairline()
  return math.max(1, dp(K.hairline))
end

local function space(value, fallback)
  return dimension(S[value] or value, fallback or 0)
end

local function radiusToken(value, fallback)
  return dimension(R[value] or value, fallback or 0)
end

local function typeSize(name)
  local item = TY[name]
  return dimension(item and item.size or TY.body.size, TY.body.size)
end

local function sizeToken(value)
  if type(value) == "string" then
    local number = numberValue(value, nil)
    if number then
      return number
    end
    return typeSize(value)
  end
  return dimension(value, TY.body.size)
end

local function timeValue(value, fallback)
  if type(value) == "string" then
    local number = value:match("^([%-+]?%d*%.?%d+)")
    number = tonumber(number)
    if number then
      return number
    end
    return fallback
  end
  return type(value) == "number" and value or fallback
end

local function colors()
  local wanted = M.isDark() and "dark" or "light"
  if M.tokens.mode ~= wanted then
    applyCurrentTheme()
  end
  return C
end

-- 注册自定义主题。顶层字段同时覆盖浅色和深色，dark 只覆盖深色差异。
function M.defineTheme(name, spec)
  spec = spec or {}
  local base = customTheme(spec.extends)
  local baseLight = base and base.light or THEMES.light
  local baseDark = base and base.dark or THEMES.dark
  local patch = {}
  for key, value in pairs(spec) do
    if key ~= "extends" and key ~= "dark" then
      patch[key] = value
    end
  end
  local light = normalizeColors(merge(baseLight, patch))
  local dark = normalizeColors(merge(merge(baseDark, patch), spec.dark or {}))
  M.customThemes = M.customThemes or {}
  M.customThemes[name] = {
    light = light,
    dark = dark,
  }
  return M.customThemes[name]
end

-- name 可以是 auto / light / dark，也可以是 defineTheme 注册的主题名。
function M.useTheme(name, mode)
  name = name or "auto"
  if name == "auto" or name == "light" or name == "dark" then
    M.appearance = name
    M.themeName = name
  else
    if not customTheme(name) then
      error("未注册的主题: " .. tostring(name))
    end
    M.themeName = name
    if mode == "light" or mode == "dark" or mode == "auto" then
      M.appearance = mode
    end
  end
  return applyCurrentTheme()
end

function M.setAppearance(mode)
  mode = mode or "auto"
  if mode ~= "auto" and mode ~= "light" and mode ~= "dark" then
    error("外观模式必须是 auto、light 或 dark")
  end
  M.appearance = mode
  if M.themeName == "light" or M.themeName == "dark" then
    M.themeName = mode
  end
  return applyCurrentTheme()
end

function M.theme()
  return {
    name = M.themeName,
    mode = M.isDark() and "dark" or "light",
    appearance = M.appearance,
  }
end

-- 按点号读取令牌；数字段会自动转成数字键，例如 spacing.16。
function M.token(path, fallback)
  local node = M.tokens
  for part in tostring(path or ""):gmatch("[^%.]+") do
    if type(node) ~= "table" then
      return fallback
    end
    local value = node[part]
    if value == nil and tonumber(part) then
      value = node[tonumber(part)]
    end
    if value == nil then
      return fallback
    end
    node = value
  end
  return node
end

local function cssColor(value)
  local alpha = (value >> 24) & 0xFF
  local red = (value >> 16) & 0xFF
  local green = (value >> 8) & 0xFF
  local blue = value & 0xFF
  if alpha == 0xFF then
    return string.format("#%02X%02X%02X", red, green, blue)
  end
  return string.format("rgba(%d, %d, %d, %.2f)", red, green, blue, alpha / 255)
end

local function cssNumber(value)
  if type(value) == "number" then
    return tostring(value)
  end
  if type(value) == "string" and value:match("^[%-+]?%d*%.?%d+$") then
    return value
  end
  return nil
end

local function cssValue(path, value)
  if path:match("^color%-") then
    return cssColor(value)
  end
  if path:match("^motion%-") then
    local number = cssNumber(value)
    return number and (number .. "ms") or tostring(value)
  end
  if path:match("^opacity%-") or path:match("%-weight$") or path:match("%-tracking$") then
    return tostring(value)
  end
  if path:match("^spacing%-") or path:match("^radius%-")
      or path:match("^control%-") or path:match("^elevation%-")
      or path:match("%-size$") or path:match("%-line%-height$") then
    local number = cssNumber(value)
    return number and (number .. "px") or tostring(value)
  end
  return tostring(value)
end

local function cssKey(key)
  return tostring(key):gsub("(%l)(%u)", "%1-%2"):lower()
end

local function flatten(prefix, value, output)
  if type(value) == "table" then
    for key, item in pairs(value) do
      local part = cssKey(key)
      flatten(prefix == "" and part or (prefix .. "-" .. part), item, output)
    end
  elseif prefix ~= "mode" then
    output[#output + 1] = string.format("  --lx-%s: %s;", prefix, cssValue(prefix, value))
  end
end

-- 导出 CSS 变量，便于 HTML/H5 或设计文档复用同一套令牌。
function M.cssVars(name, mode)
  local theme
  if name == nil or name == "current" then
    theme = currentTheme()
  elseif name == "light" or name == "dark" then
    theme = THEMES[name]
  else
    local custom = customTheme(name)
    if not custom then
      error("未注册的主题: " .. tostring(name))
    end
    theme = (mode == "dark" or (mode ~= "light" and M.isDark())) and custom.dark or custom.light
  end
  local output = {}
  flatten("", theme, output)
  return ":root {\n" .. table.concat(output, "\n") .. "\n}"
end

-- ===== 基础绘制 =====
local function shape(fill, stroke, radius)
  local drawable = GradientDrawable()
  drawable.setShape(GradientDrawable.RECTANGLE)
  drawable.setColor(fill)
  drawable.setCornerRadius(dp(radiusToken(radius)))
  if stroke then
    drawable.setStroke(hairline(), stroke)
  end
  return drawable
end

local function overlay(color, alpha)
  return (alpha << 24) | (color & 0x00FFFFFF)
end

local function ripple(fill, radius, color)
  local content = shape(fill, nil, radius)
  local ok, drawable = pcall(function()
    return RippleDrawable(ColorStateList.valueOf(color), content, content)
  end)
  if ok and drawable then
    return drawable
  end
  return content
end

local function roundRect(fill, radius)
  return shape(fill, nil, radius)
end

local function textView(text, size, color, bold)
  local view = TextView(activity)
  view.setText(tostring(text or ""))
  view.setTextSize(sizeToken(size))
  view.setTextColor(color)
  if bold then
    view.setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL))
  else
    view.setTypeface(Typeface.create("sans-serif", Typeface.NORMAL))
  end
  return view
end

local function applySystemBars(dark, background, statusBar, navigationBar)
  local current = activity
  if not current then
    return
  end
  pcall(function()
    local window = current.getWindow()
    local params = luajava.bindClass("android.view.WindowManager$LayoutParams")
    window.addFlags(params.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
    window.clearFlags(params.FLAG_TRANSLUCENT_STATUS)
    window.clearFlags(params.FLAG_TRANSLUCENT_NAVIGATION)
  end)
  pcall(function()
    local window = current.getWindow()
    window.setStatusBarColor(statusBar or background)
    window.setNavigationBarColor(navigationBar or background)
    window.setBackgroundDrawable(ColorDrawable(background))
  end)
  pcall(function()
    local decor = current.getWindow().getDecorView()
    local flags = decor.getSystemUiVisibility()
    if Build.VERSION.SDK_INT >= 23 then
      if dark then
        flags = flags & ~8192
      else
        flags = flags | 8192
      end
      decor.setSystemUiVisibility(flags)
    end
    if Build.VERSION.SDK_INT >= 26 then
      if dark then
        flags = flags & ~16
      else
        flags = flags | 16
      end
      decor.setSystemUiVisibility(flags)
    end
  end)
end

-- ===== 图片、透明度与背景 =====
local function alphaRatio(value, fallback)
  if value == nil then
    return fallback == nil and 1 or fallback
  end
  if type(value) == "string" and OP[value] ~= nil then
    value = OP[value]
  elseif type(value) == "string" then
    local number = numberValue(value, nil)
    if number == nil then
      return fallback == nil and 1 or fallback
    end
    value = number
  end
  if type(value) ~= "number" then
    return fallback == nil and 1 or fallback
  end
  if value > 1 then
    value = value / 255
  end
  if value < 0 then
    return 0
  end
  if value > 1 then
    return 1
  end
  return value
end

local function alphaByte(value)
  return math.floor(alphaRatio(value, 1) * 255 + 0.5)
end

local function alphaValue(value)
  return alphaRatio(value, 1)
end

-- 将颜色按透明度混合，0-1 或 0-255 都接受。
function M.withAlpha(color, opacity)
  return overlay(parseColor(color), alphaByte(opacity))
end

local function bitmapSource(source)
  if source == nil then
    return nil
  end
  if type(source) == "userdata" and source.getWidth and source.getHeight then
    return source
  end
  if type(source) ~= "string" then
    return nil
  end
  local loader = _G.loadbitmap
  if loader then
    local ok, bitmap = pcall(loader, source)
    if ok and bitmap then
      return bitmap
    end
  end
  local ok, bitmap = pcall(BitmapFactory.decodeFile, source)
  if ok then
    return bitmap
  end
  return nil
end

local function roundedBitmap(bitmap, radius)
  local resources = activity.getResources()
  if radius then
    local ok, factory = pcall(luajava.bindClass, "androidx.core.graphics.drawable.RoundedBitmapDrawableFactory")
    if ok and factory then
      local drawable = factory.create(resources, bitmap)
      if radius == "circle" then
        drawable.setCircular(true)
      else
        drawable.setCornerRadius(dp(radiusToken(radius)))
      end
      drawable.setAntiAlias(true)
      return drawable
    end
  end
  return BitmapDrawable(resources, bitmap)
end

local function drawableSource(source, radius)
  if source == nil then
    return nil
  end
  if type(source) == "number" then
    return activity.getResources().getDrawable(source)
  end
  if type(source) == "userdata" and source.getIntrinsicWidth then
    return source
  end
  if type(source) == "userdata" and source.getBitmap then
    return roundedBitmap(source.getBitmap(), radius)
  end
  local bitmap = bitmapSource(source)
  if bitmap then
    return roundedBitmap(bitmap, radius)
  end
  return nil
end

local function imageScale(value)
  if value == "contain" then
    return ImageView.ScaleType.FIT_CENTER
  elseif value == "fill" then
    return ImageView.ScaleType.FIT_XY
  elseif value == "center" then
    return ImageView.ScaleType.CENTER
  elseif value == "inside" then
    return ImageView.ScaleType.FIT_START
  end
  return ImageView.ScaleType.CENTER_CROP
end

-- 图片组件：支持本地路径、网络缓存路径、Bitmap、Drawable 和资源 id。
function M.image(spec)
  if type(spec) == "string" then
    spec = { src = spec }
  end
  spec = spec or {}
  local view = ImageView(activity)
  view.setScaleType(imageScale(spec.scale))
  view.setAdjustViewBounds(spec.adjust ~= false)
  local source = spec.src or spec.path or spec.image
  local radius = spec.radius
  if spec.circle then
    radius = "circle"
  end
  local drawable = drawableSource(source, radius)
  if drawable then
    view.setImageDrawable(drawable)
  else
    view.setBackgroundColor(parseColor(spec.placeholder or colors().fill))
  end
  if spec.alpha ~= nil then
    view.setAlpha(alphaValue(spec.alpha))
  end
  if spec.tint then
    view.setColorFilter(parseColor(spec.tint))
  end
  if spec.width then
    view.setMinimumWidth(dp(space(spec.width)))
  end
  if spec.height then
    view.setMinimumHeight(dp(space(spec.height)))
  end
  return view
end

-- 背景卡片：图片铺底 + 可调遮罩 + 内容层，适合头图、登录页和专题卡。
function M.background(spec, content)
  if type(spec) == "string" then
    spec = { src = spec }
  end
  spec = spec or {}
  local palette = colors()
  local frame = FrameLayout(activity)
  if spec.radius then
    frame.setClipToOutline(true)
    frame.setBackground(roundRect(parseColor(spec.background or 0x00000000), spec.radius))
  elseif spec.background then
    frame.setBackgroundColor(parseColor(spec.background))
  end
  if spec.src then
    local image = M.image({
      src = spec.src,
      scale = spec.scale or "cover",
      radius = spec.radius,
      alpha = spec.alpha,
      tint = spec.tint,
      adjust = false,
    })
    frame.addView(image, FrameLayout.LayoutParams(-1, -1))
  end
  if spec.overlay ~= false then
    local scrim = View(activity)
    scrim.setBackgroundColor(parseColor(spec.overlay or palette.scrim))
    frame.addView(scrim, FrameLayout.LayoutParams(-1, -1))
  end
  if content then
    local body = LinearLayout(activity)
    body.setOrientation(LinearLayout.VERTICAL)
    body.setGravity(spec.gravity or Gravity.CENTER_VERTICAL)
    local padding = spec.contentPadding or S.card
    body.setPadding(dp(space(padding)), dp(space(padding)), dp(space(padding)), dp(space(padding)))
    if type(content) == "function" then
      content(body, frame)
    else
      body.addView(content, LinearLayout.LayoutParams(-1, -2))
    end
    frame.addView(body, FrameLayout.LayoutParams(-1, -1))
  end
  if spec.height then
    frame.setMinimumHeight(dp(space(spec.height)))
  end
  return frame
end

-- ===== 页面骨架 =====
function M.page(options)
  options = options or {}
  local dark = M.isDark()
  local palette = colors()
  local current = activity
  if not current then
    error("LuaX-UI 需要在 Activity 脚本中使用")
  end

  pcall(function()
    local actionBar = current.getActionBar()
    if actionBar then
      actionBar.hide()
    end
  end)
  pcall(function()
    local supportBar = current.getSupportActionBar()
    if supportBar then
      supportBar.hide()
    end
  end)
  local background = parseColor(options.background or palette.bg)
  local statusBar = parseColor(options.statusBarBackground or palette.bg)
  local navigationBar = parseColor(options.navigationBarBackground or palette.bg)
  if not dark and Build.VERSION.SDK_INT < 23 then
    statusBar = palette.ink
  end
  applySystemBars(dark, background, statusBar, navigationBar)

  local frame = FrameLayout(current)
  frame.setFitsSystemWindows(true)

  local root = LinearLayout(current)
  root.setOrientation(LinearLayout.VERTICAL)
  if options.backgroundImage then
    local backdrop = M.image({
      src = options.backgroundImage,
      scale = options.backgroundScale or "cover",
      alpha = options.backgroundAlpha,
    })
    frame.addView(backdrop, FrameLayout.LayoutParams(-1, -1))
    if options.backgroundOverlay ~= false then
      local scrim = View(current)
      scrim.setBackgroundColor(parseColor(options.backgroundOverlay or palette.scrim))
      frame.addView(scrim, FrameLayout.LayoutParams(-1, -1))
    end
    root.setBackgroundColor(0x00000000)
  else
    root.setBackgroundColor(parseColor(options.background or palette.bg))
  end
  frame.addView(root, FrameLayout.LayoutParams(-1, -1))

  local nav = FrameLayout(current)
  nav.setBackgroundColor(options.navBackground or palette.bg)
  root.addView(nav, LinearLayout.LayoutParams(-1, dp(K.navHeight)))

  local navTitle = textView(options.title or "", TY.body.size, palette.label, true)
  navTitle.setGravity(Gravity.CENTER)
  local titleParams = FrameLayout.LayoutParams(-2, -2)
  titleParams.gravity = Gravity.CENTER
  nav.addView(navTitle, titleParams)

  if options.back then
    local back = icons.view("chevron-left", { size = 22, color = palette.accent })
    back.setPadding(dp(space(4)), 0, dp(space(4)), 0)
    back.setBackground(ripple(0x00000000, R.nav, palette.press))
    local backParams = FrameLayout.LayoutParams(dp(K.navHeight), -1)
    backParams.gravity = Gravity.LEFT
    nav.addView(back, backParams)
    back.setOnClickListener(View.OnClickListener{
      onClick = function()
        local handler = options.onBack
        if handler then
          handler()
        else
          current.finish()
        end
      end
    })
  end

  local rightSpec = options.right
  if type(rightSpec) == "string" then
    rightSpec = { title = rightSpec }
  end
  if rightSpec then
    local right = textView(rightSpec.title or "完成", TY.body.size, palette.accent, true)
    right.setGravity(Gravity.CENTER)
    right.setPadding(dp(space(12)), 0, dp(space(12)), 0)
    right.setBackground(ripple(0x00000000, R.nav, palette.press))
    local rightParams = FrameLayout.LayoutParams(-2, -1)
    rightParams.gravity = Gravity.RIGHT
    nav.addView(right, rightParams)
    if rightSpec.onClick then
      right.setOnClickListener(View.OnClickListener{
        onClick = rightSpec.onClick
      })
    end
  end

  local navLine = View(current)
  navLine.setBackgroundColor(palette.separator)
  local lineParams = FrameLayout.LayoutParams(-1, hairline())
  lineParams.gravity = Gravity.BOTTOM
  nav.addView(navLine, lineParams)

  if options.largeTitle ~= false and options.title then
    local large = textView(options.title, TY.display.size, palette.label, true)
    large.setPadding(dp(space(16)), dp(space(8)), dp(space(16)), dp(space(2)))
    large.setIncludeFontPadding(false)
    root.addView(large, LinearLayout.LayoutParams(-1, -2))
    if options.subtitle then
      local subtitle = textView(options.subtitle, TY.footnote.size, palette.secondary, false)
      subtitle.setPadding(dp(space(16)), 0, dp(space(16)), dp(space(10)))
      root.addView(subtitle, LinearLayout.LayoutParams(-1, -2))
    end
  elseif options.subtitle then
    local subtitle = textView(options.subtitle, TY.footnote.size, palette.secondary, false)
    subtitle.setPadding(dp(space(16)), 0, dp(space(16)), dp(space(8)))
    root.addView(subtitle, LinearLayout.LayoutParams(-1, -2))
  end

  local scroll = ScrollView(current)
  scroll.setFillViewport(true)
  scroll.setVerticalScrollBarEnabled(false)
  local content = LinearLayout(current)
  content.setOrientation(LinearLayout.VERTICAL)
  content.setPadding(dp(space(16)), dp(space(8)), dp(space(16)), dp(space(32)))
  scroll.addView(content, LinearLayout.LayoutParams(-1, -2))
  root.addView(scroll, LinearLayout.LayoutParams(-1, 0, 1))

  local page = {
    frame = frame,
    root = root,
    nav = nav,
    content = content,
    scroll = scroll,
    titleView = navTitle,
    dark = dark,
  }

  function page:add(view, topMargin)
    if view == nil then
      return self
    end
    local params = LinearLayout.LayoutParams(-1, -2)
    params.topMargin = dp(space(topMargin or 0))
    content.addView(view, params)
    return self
  end

  function page:addGroup(header, rows, footer)
    self:add(M.group(header, rows, footer))
    return self
  end

  function page:setTitle(value)
    navTitle.setText(tostring(value or ""))
    return self
  end

  function page:show()
    current.setContentView(frame)
    return self
  end

  function page:reveal(spec)
    if spec == true or spec == nil then
      spec = {}
    end
    local views = {}
    for index = 0, content.getChildCount() - 1 do
      views[#views + 1] = content.getChildAt(index)
    end
    M.stagger(views, spec)
    return self
  end

  return page
end

-- ===== 分组列表 =====
local function separatorView(leftInset)
  local line = View(activity)
  line.setBackgroundColor(colors().separator)
  local params = LinearLayout.LayoutParams(-1, hairline())
  params.leftMargin = dp(space(leftInset or 16))
  return line, params
end

function M.row(spec)
  spec = spec or {}
  local palette = colors()
  local row = LinearLayout(activity)
  row.setOrientation(LinearLayout.HORIZONTAL)
  row.setGravity(Gravity.CENTER_VERTICAL)
  row.setMinimumHeight(dp(space(spec.height or K.rowHeight)))
  row.setPadding(dp(space(spec.icon and 12 or 16)), dp(space(7)), dp(space(12)), dp(space(7)))
  row.setBackground(ripple(0x00000000, 0, palette.press))

  if spec.icon then
    if type(spec.icon) == "string" and icons.has(spec.icon) then
      local bg = parseColor(spec.iconBg or palette.accent)
      local badge = icons.chip(spec.icon, {
        size = K.iconBadge,
        iconSize = math.max(13, K.iconBadge - 13),
        background = bg,
        color = spec.iconColor or icons.contrast(bg),
        radius = R.iconBadge,
      })
      local params = LinearLayout.LayoutParams(dp(K.iconBadge), dp(K.iconBadge))
      params.rightMargin = dp(space(11))
      row.addView(badge, params)
    elseif type(spec.icon) == "string" then
      local badge = textView(spec.icon, TY.callout.size, palette.onAccent, true)
      badge.setGravity(Gravity.CENTER)
      badge.setBackground(roundRect(parseColor(spec.iconBg or palette.accent), R.iconBadge))
      local params = LinearLayout.LayoutParams(dp(K.iconBadge), dp(K.iconBadge))
      params.rightMargin = dp(space(11))
      row.addView(badge, params)
    else
      local params = LinearLayout.LayoutParams(dp(K.iconBadge), dp(K.iconBadge))
      params.rightMargin = dp(space(11))
      row.addView(spec.icon, params)
    end
  end

  local textBox = LinearLayout(activity)
  textBox.setOrientation(LinearLayout.VERTICAL)
  row.addView(textBox, LinearLayout.LayoutParams(0, -2, 1))

  local titleColor = spec.destructive and palette.danger or palette.label
  local title = textView(spec.title or "", spec.titleSize or TY.body.size, titleColor, false)
  title.setSingleLine(true)
  title.setEllipsize(TextUtils.TruncateAt.END)
  textBox.addView(title)

  if spec.subtitle then
    local subtitle = textView(spec.subtitle, TY.footnote.size, palette.secondary, false)
    subtitle.setSingleLine(true)
    subtitle.setEllipsize(TextUtils.TruncateAt.END)
    subtitle.setPadding(0, dp(space(2)), 0, 0)
    textBox.addView(subtitle)
  end

  if spec.value then
    local value = textView(spec.value, TY.callout.size, palette.secondary, false)
    value.setSingleLine(true)
    value.setPadding(dp(space(8)), 0, dp(space(2)), 0)
    row.addView(value)
  end

  if spec.accessory then
    row.addView(spec.accessory)
  elseif spec.toggle ~= nil or spec.onToggle then
    local switchView
    local ok = pcall(function()
      local IosSwitch = luajava.bindClass("com.mini.luaxplus.ui.IosSwitch")
      switchView = luajava.new(IosSwitch, activity)
    end)
    if not ok or not switchView then
      switchView = Switch(activity)
      switchView.setShowText(false)
    else
      pcall(function()
        switchView.setTrackColors(palette.fill, palette.success)
      end)
    end
    local checked = spec.toggle == true
    switchView.setChecked(checked)
    row.addView(switchView)
    local listener = spec.onToggle
    switchView.setOnCheckedChangeListener(CompoundButton.OnCheckedChangeListener{
      onCheckedChanged = function(button, state)
        spec.toggle = state
        if listener then
          listener(state)
        end
      end
    })
    if not spec.onClick then
      row.setOnClickListener(View.OnClickListener{
        onClick = function()
          switchView.setChecked(not switchView.isChecked())
        end
      })
    end
  elseif spec.selected then
    local check = icons.view("check", { size = 16, color = palette.accent })
    check.setPadding(0, 0, 0, 0)
    local checkParams = LinearLayout.LayoutParams(dp(16), dp(16))
    checkParams.leftMargin = dp(space(6))
    row.addView(check, checkParams)
  elseif spec.chevron ~= false and (spec.onClick or spec.chevron) then
    local chevron = icons.view("chevron-right", { size = 16, color = palette.tertiary })
    chevron.setPadding(0, 0, 0, 0)
    local chevronParams = LinearLayout.LayoutParams(dp(16), dp(16))
    chevronParams.leftMargin = dp(space(6))
    row.addView(chevron, chevronParams)
  end

  if spec.disabled then
    row.setAlpha(alphaValue(OP.disabled))
    row.setEnabled(false)
  elseif spec.onClick then
    row.setOnClickListener(View.OnClickListener{
      onClick = spec.onClick
    })
  end

  return row
end

function M.group(header, rows, footer)
  local palette = colors()
  local box = LinearLayout(activity)
  box.setOrientation(LinearLayout.VERTICAL)

  if header then
    local caption = textView(string.upper(tostring(header)), TY.footnote.size, palette.secondary, false)
    caption.setLetterSpacing(numberValue(TY.caption.tracking, 0.04))
    caption.setPadding(dp(space(4)), dp(space(6)), dp(space(4)), dp(space(6)))
    box.addView(caption)
  end

  local card = LinearLayout(activity)
  card.setOrientation(LinearLayout.VERTICAL)
  card.setBackground(roundRect(palette.surface, R.card))
  card.setClipToOutline(true)
  box.addView(card, LinearLayout.LayoutParams(-1, -2))

  local items = rows or {}
  if type(items) ~= "table" then
    items = { items }
  end

  local viewCount = 0
  for index = 1, #items do
    local item = items[index]
    local view = item
    if type(item) == "table" and item.view then
      view = item.view
    elseif type(item) == "table" and (item.title or item.toggle ~= nil or item.onClick or item.icon) then
      view = M.row(item)
    end
    if view then
      if viewCount > 0 then
        local line, params = separatorView(16)
        card.addView(line, params)
      end
      card.addView(view, LinearLayout.LayoutParams(-1, -2))
      viewCount = viewCount + 1
    end
  end

  if footer then
    local note = textView(tostring(footer), TY.footnote.size, palette.secondary, false)
    note.setPadding(dp(space(4)), dp(space(7)), dp(space(4)), dp(space(4)))
    box.addView(note)
  end

  return box
end

M.section = M.group

-- ===== 按钮 =====
function M.button(spec)
  if type(spec) == "string" then
    spec = { text = spec }
  end
  spec = spec or {}
  local palette = colors()
  local style = spec.style or "filled"
  local fill, textColor, rippleColor
  if style == "filled" then
    fill = palette.accent
    textColor = palette.onAccent
    rippleColor = palette.pressOnAccent
  elseif style == "tinted" then
    fill = palette.accentSoft
    textColor = palette.accent
    rippleColor = overlay(palette.accent, alphaByte(OP.light))
  elseif style == "gray" then
    fill = palette.fill
    textColor = palette.label
    rippleColor = palette.pressStrong
  elseif style == "plain" then
    fill = 0x00000000
    textColor = palette.accent
    rippleColor = overlay(palette.accent, alphaByte(OP.subtle))
  elseif style == "destructive" then
    fill = palette.danger
    textColor = palette.onAccent
    rippleColor = palette.pressOnAccent
  else
    fill = palette.accent
    textColor = palette.onAccent
    rippleColor = palette.pressOnAccent
  end

  local button = textView(spec.text or "按钮", spec.textSize or TY.body.size, textColor, true)
  button.setGravity(Gravity.CENTER)
  button.setPadding(dp(space("buttonX")), dp(space("buttonY")), dp(space("buttonX")), dp(space("buttonY")))
  button.setMinimumHeight(dp(K.buttonHeight))
  button.setBackground(ripple(fill, spec.radius or R.button, rippleColor))
  if spec.enabled == false then
    button.setAlpha(alphaValue(OP.disabled))
    button.setEnabled(false)
  elseif spec.onClick then
    button.setOnClickListener(View.OnClickListener{
      onClick = spec.onClick
    })
  end
  return button
end

-- ===== 输入 =====
local function configureInput(input, spec)
  local palette = colors()
  input.setTextSize(sizeToken(spec.textSize or TY.body.size))
  input.setTextColor(palette.label)
  input.setHintTextColor(palette.tertiary)
  input.setBackgroundColor(0x00000000)
  input.setPadding(0, 0, 0, 0)
  input.setSingleLine(spec.multiline ~= true)
  if spec.multiline then
    input.setGravity(Gravity.TOP)
    input.setMinLines(spec.lines or 4)
  end
  if spec.secure then
    input.setInputType(0x00000080)
  elseif spec.numeric then
    input.setInputType(0x00000002)
  elseif spec.email then
    input.setInputType(0x00000021)
  elseif spec.phone then
    input.setInputType(0x00000003)
  end
  if spec.value ~= nil then
    input.setText(tostring(spec.value))
  end
  local hint = spec.hint or spec.placeholder
  if hint then
    input.setHint(hint)
  end
  if spec.onChange then
    input.addTextChangedListener(TextWatcher{
      beforeTextChanged = function()
      end,
      onTextChanged = function()
      end,
      afterTextChanged = function(editable)
        spec.onChange(tostring(editable.toString()))
      end
    })
  end
  return input
end

function M.fieldRow(spec)
  spec = spec or {}
  local palette = colors()
  local row = LinearLayout(activity)
  row.setOrientation(LinearLayout.HORIZONTAL)
  row.setGravity(Gravity.CENTER_VERTICAL)
  row.setMinimumHeight(dp(K.inputHeight))
  row.setPadding(dp(space(16)), dp(space(7)), dp(space(16)), dp(space(7)))

  local label = textView(spec.label or "字段", TY.body.size, palette.label, false)
  label.setSingleLine(true)
  row.addView(label)

  local input = EditText(activity)
  configureInput(input, spec)
  input.setGravity(Gravity.RIGHT)
  local params = LinearLayout.LayoutParams(0, -2, 1)
  params.leftMargin = dp(space(12))
  row.addView(input, params)

  return { view = row, input = input }
end

function M.field(spec)
  spec = spec or {}
  local palette = colors()
  local box = LinearLayout(activity)
  box.setOrientation(LinearLayout.VERTICAL)
  if spec.label then
    local label = textView(spec.label, TY.footnote.size, palette.secondary, false)
    label.setPadding(dp(space(4)), dp(space(6)), dp(space(4)), dp(space(6)))
    box.addView(label)
  end
  local holder = LinearLayout(activity)
  holder.setOrientation(LinearLayout.VERTICAL)
  holder.setBackground(roundRect(palette.surface, R.input))
  holder.setPadding(dp(space(16)), dp(space(10)), dp(space(16)), dp(space(10)))
  local input = EditText(activity)
  configureInput(input, spec)
  holder.addView(input, LinearLayout.LayoutParams(-1, -2))
  box.addView(holder, LinearLayout.LayoutParams(-1, -2))
  if spec.footer then
    local note = textView(spec.footer, TY.footnote.size, palette.secondary, false)
    note.setPadding(dp(space(4)), dp(space(6)), dp(space(4)), 0)
    box.addView(note)
  end
  return { view = box, input = input }
end

function M.textArea(spec)
  spec = spec or {}
  spec.multiline = true
  return M.field(spec)
end

function M.searchBar(spec)
  spec = spec or {}
  local palette = colors()
  local bar = LinearLayout(activity)
  bar.setOrientation(LinearLayout.HORIZONTAL)
  bar.setGravity(Gravity.CENTER_VERTICAL)
  bar.setBackground(roundRect(palette.fill, R.search))
  bar.setPadding(dp(space(10)), 0, dp(space(10)), 0)

  local glyph = icons.view("search", { size = 17, color = palette.secondary })
  glyph.setPadding(0, 0, 0, 0)
  bar.addView(glyph, LinearLayout.LayoutParams(dp(17), dp(17)))

  local input = EditText(activity)
  configureInput(input, {
    hint = spec.hint or "搜索",
    value = spec.value,
    onChange = spec.onChange,
  })
  input.setTextSize(sizeToken(TY.callout.size))
  local params = LinearLayout.LayoutParams(0, dp(K.searchHeight), 1)
  params.leftMargin = dp(space(6))
  bar.addView(input, params)

  return bar
end

-- ===== 分段选择 =====
function M.segmented(spec)
  spec = spec or {}
  local palette = colors()
  local track = LinearLayout(activity)
  track.setOrientation(LinearLayout.HORIZONTAL)
  track.setBackground(roundRect(palette.fill, R.segment))
  track.setPadding(dp(space(2)), dp(space(2)), dp(space(2)), dp(space(2)))

  local labels = {}
  local items = spec.items or {}
  local selected = spec.selected or 1

  local function apply()
    for index = 1, #labels do
      local item = labels[index]
      if index == selected then
        item.setBackground(roundRect(palette.surface, R.segmentItem))
        item.setTextColor(palette.label)
        item.setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL))
      else
        item.setBackgroundColor(0x00000000)
        item.setTextColor(palette.label)
        item.setTypeface(Typeface.create("sans-serif", Typeface.NORMAL))
      end
    end
  end

  for index = 1, #items do
    local value = items[index]
    if type(value) == "table" then
      value = value.title or value.text or ""
    end
    local label = textView(value, TY.footnote.size, palette.label, false)
    label.setGravity(Gravity.CENTER)
    label.setPadding(dp(space(6)), dp(space(6)), dp(space(6)), dp(space(6)))
    track.addView(label, LinearLayout.LayoutParams(0, dp(K.segment), 1))
    labels[index] = label
    label.setOnClickListener(View.OnClickListener{
      onClick = function()
        selected = index
        apply()
        if spec.onChange then
          spec.onChange(index, items[index])
        end
      end
    })
  end
  apply()

  return {
    view = track,
    getSelected = function()
      return selected
    end,
    setSelected = function(index)
      selected = index
      apply()
    end,
  }
end

-- ===== 卡片、空态、加载 =====
function M.card(spec, content)
  spec = spec or {}
  local palette = colors()
  local card = LinearLayout(activity)
  card.setOrientation(LinearLayout.VERTICAL)
  card.setBackground(roundRect(palette.surface, R.card))
  card.setPadding(dp(space(16)), dp(space(16)), dp(space(16)), dp(space(16)))

  if spec.title then
    local title = textView(spec.title, spec.titleSize or TY.body.size, palette.label, true)
    card.addView(title)
  end
  if spec.subtitle then
    local subtitle = textView(spec.subtitle, TY.subhead.size, palette.secondary, false)
    subtitle.setPadding(0, dp(space(4)), 0, 0)
    card.addView(subtitle)
  end
  if content then
    local params = LinearLayout.LayoutParams(-1, -2)
    params.topMargin = dp(space(10))
    if type(content) == "function" then
      local holder = LinearLayout(activity)
      holder.setOrientation(LinearLayout.VERTICAL)
      card.addView(holder, params)
      content(holder, card)
    else
      card.addView(content, params)
    end
  end
  return card
end

function M.empty(spec)
  spec = spec or {}
  local palette = colors()
  local box = LinearLayout(activity)
  box.setOrientation(LinearLayout.VERTICAL)
  box.setGravity(Gravity.CENTER)
  box.setPadding(dp(space(24)), dp(space(44)), dp(space(24)), dp(space(44)))

  local glyph
  local emptyIcon = spec.icon or "empty"
  if type(emptyIcon) == "string" and icons.has(emptyIcon) then
    local bg = parseColor(spec.iconBackground or palette.accentSoft)
    glyph = icons.chip(emptyIcon, {
      size = 58,
      iconSize = 28,
      background = bg,
      color = spec.color or icons.contrast(bg),
      radius = 18,
    })
  elseif type(emptyIcon) == "string" then
    glyph = textView(emptyIcon, TY.emptyGlyph.size, palette.tertiary, false)
    glyph.setGravity(Gravity.CENTER)
  else
    glyph = emptyIcon
  end
  box.addView(glyph)

  local title = textView(spec.title or "暂无内容", TY.body.size, palette.label, true)
  title.setGravity(Gravity.CENTER)
  title.setPadding(0, dp(space(12)), 0, 0)
  box.addView(title)

  if spec.message then
    local message = textView(spec.message, TY.subhead.size, palette.secondary, false)
    message.setGravity(Gravity.CENTER)
    message.setPadding(0, dp(space(6)), 0, 0)
    box.addView(message)
  end

  if spec.action then
    local action = M.button{
      text = spec.action.title or "去看看",
      style = "tinted",
      onClick = spec.action.onClick,
    }
    local params = LinearLayout.LayoutParams(-2, dp(space(46)))
    params.topMargin = dp(space(16))
    box.addView(action, params)
  end
  return box
end

function M.loading(spec)
  spec = spec or {}
  local palette = colors()
  local box = LinearLayout(activity)
  box.setOrientation(LinearLayout.VERTICAL)
  box.setGravity(Gravity.CENTER)
  box.setPadding(dp(space(24)), dp(space(36)), dp(space(24)), dp(space(36)))

  local progress = ProgressBar(activity)
  progress.setIndeterminate(true)
  pcall(function()
    progress.getIndeterminateDrawable().setColorFilter(palette.accent, PorterDuff.Mode.SRC_IN)
  end)
  box.addView(progress, LinearLayout.LayoutParams(dp(space(28)), dp(space(28))))

  local label = textView(spec.text or "加载中…", TY.subhead.size, palette.secondary, false)
  label.setGravity(Gravity.CENTER)
  label.setPadding(0, dp(space(10)), 0, 0)
  box.addView(label)
  return box
end

function M.avatar(name, color, size)
  local palette = colors()
  local initial = "?"
  local text = tostring(name or "")
  if text ~= "" then
    -- 按 UTF-8 码点取首字，避免中文被按字节截成“?”。
    local ok, first = pcall(function()
      return utf8.char(utf8.codepoint(text, 1))
    end)
    initial = ok and first or string.sub(text, 1, 1)
  end
  local avatarSize = dimension(size or K.avatar, K.avatar)
  local avatarFont = math.floor(avatarSize / numberValue(K.avatarFontRatio, 2.4))
  local avatar = textView(string.upper(initial), avatarFont, palette.onAccent, true)
  avatar.setGravity(Gravity.CENTER)
  avatar.setIncludeFontPadding(false)
  avatar.setBackground(roundRect(parseColor(color or palette.accent), avatarSize / 2))
  local extent = dp(avatarSize)
  pcall(function()
    avatar.setMinimumWidth(extent)
    avatar.setMinimumHeight(extent)
  end)
  -- 父容器重新添加 View 时会覆盖 LayoutParams，这里同时锁住测量尺寸。
  pcall(function()
    avatar.setMaxWidth(extent)
    avatar.setMaxHeight(extent)
  end)
  avatar.setLayoutParams(LinearLayout.LayoutParams(extent, extent))
  return avatar
end

function M.badge(text, color)
  local palette = colors()
  local badge = textView(text or "", TY.caption.size, parseColor(color or palette.danger), true)
  badge.setGravity(Gravity.CENTER)
  badge.setPadding(dp(space(6)), dp(space(2)), dp(space(6)), dp(space(2)))
  badge.setBackground(roundRect(palette.fill, R.badge))
  return badge
end

function M.divider(leftInset)
  local line, params = separatorView(leftInset or 0)
  local holder = LinearLayout(activity)
  holder.setOrientation(LinearLayout.HORIZONTAL)
  holder.addView(line, params)
  return holder
end

function M.spacer(height)
  local view = View(activity)
  view.setMinimumHeight(dp(space(height or 12)))
  return view
end

function M.tabBar(spec)
  spec = spec or {}
  local palette = colors()
  local bar = LinearLayout(activity)
  bar.setOrientation(LinearLayout.HORIZONTAL)
  bar.setBackgroundColor(palette.surface)
  bar.setPadding(0, dp(space(4)), 0, dp(space(6)))

  local topLine = View(activity)
  topLine.setBackgroundColor(palette.separator)
  local topParams = LinearLayout.LayoutParams(-1, hairline())

  local tabs = {}
  local selected = spec.selected or 1
  local items = spec.items or {}

  local function apply()
    for index = 1, #tabs do
      local tab = tabs[index]
      local active = index == selected
      local color = active and palette.accent or palette.secondary
      if tab.iconIsImage then
        pcall(function()
          tab.icon.setColorFilter(color)
        end)
      else
        tab.icon.setTextColor(color)
      end
      tab.label.setTextColor(color)
      tab.label.setTypeface(Typeface.create(active and "sans-serif-medium" or "sans-serif", Typeface.NORMAL))
    end
  end

  for index = 1, #items do
    local item = items[index]
    if type(item) ~= "table" then
      item = { title = tostring(item) }
    end
    local tab = LinearLayout(activity)
    tab.setOrientation(LinearLayout.VERTICAL)
    tab.setGravity(Gravity.CENTER)
    tab.setPadding(0, dp(space(4)), 0, dp(space(2)))

    local iconName = item.icon or item.glyph
    local icon
    local iconIsImage = type(iconName) == "string" and icons.has(iconName)
    if iconIsImage then
      icon = icons.view(iconName, { size = 20, color = palette.secondary })
    else
      icon = textView(iconName or "•", TY.icon.size, palette.secondary, false)
      icon.setGravity(Gravity.CENTER)
    end
    tab.addView(icon)

    local label = textView(item.title or "", TY.micro.size, palette.secondary, false)
    label.setGravity(Gravity.CENTER)
    tab.addView(label)

    bar.addView(tab, LinearLayout.LayoutParams(0, dp(K.tabHeight), 1))
    tab.setOnClickListener(View.OnClickListener{
      onClick = function()
        selected = index
        apply()
        if spec.onChange then
          spec.onChange(index, item)
        end
      end
    })
    tabs[index] = { icon = icon, label = label, root = tab, iconIsImage = iconIsImage }
  end
  apply()

  -- 返回一个带顶部分割线的容器，便于直接放到页面底部
  local holder = LinearLayout(activity)
  holder.setOrientation(LinearLayout.VERTICAL)
  holder.addView(topLine, topParams)
  holder.addView(bar, LinearLayout.LayoutParams(-1, -2))
  return {
    view = holder,
    setSelected = function(index)
      selected = index
      apply()
    end,
  }
end

-- ===== iOS 弹窗 =====
function M.alert(spec)
  spec = spec or {}
  local palette = colors()
  local current = activity
  local dialog = Dialog(current)
  dialog.requestWindowFeature(1)
  dialog.setCanceledOnTouchOutside(spec.dismissible ~= false)

  local card = LinearLayout(current)
  card.setOrientation(LinearLayout.VERTICAL)
  card.setBackground(roundRect(palette.surface, R.dialog))
  card.setClipToOutline(true)

  local title = textView(spec.title or "提示", TY.body.size, palette.label, true)
  title.setGravity(Gravity.CENTER)
  title.setPadding(dp(space(19)), dp(space(19)), dp(space(19)), 0)
  card.addView(title, LinearLayout.LayoutParams(-1, -2))

  if spec.message then
    local message = textView(spec.message, TY.footnote.size, palette.secondary, false)
    message.setGravity(Gravity.CENTER)
    message.setPadding(dp(space(19)), dp(space(7)), dp(space(19)), dp(space(19)))
    card.addView(message, LinearLayout.LayoutParams(-1, -2))
  else
    local gap = View(current)
    gap.setLayoutParams(LinearLayout.LayoutParams(1, dp(space(10))))
    card.addView(gap)
  end

  local actions = spec.actions or {}
  if #actions == 0 then
    actions = { { title = "好" } }
  end

  local function makeAction(action)
    local color = palette.accent
    if action.style == "destructive" then
      color = palette.danger
    end
    local button = textView(action.title or "好", TY.body.size, color, action.style == "cancel")
    button.setGravity(Gravity.CENTER)
    button.setBackground(ripple(0x00000000, 0, palette.press))
    button.setOnClickListener(View.OnClickListener{
      onClick = function()
        local keep = false
        if action.onClick then
          keep = action.onClick() == false
        end
        if not keep then
          dialog.dismiss()
        end
      end
    })
    return button
  end

  if #actions <= 2 then
    local line = View(current)
    line.setBackgroundColor(palette.separator)
    card.addView(line, LinearLayout.LayoutParams(-1, hairline()))

    local row = LinearLayout(current)
    row.setOrientation(LinearLayout.HORIZONTAL)
    for index = 1, #actions do
      if index > 1 then
        local divider = View(current)
        divider.setBackgroundColor(palette.separator)
        row.addView(divider, LinearLayout.LayoutParams(hairline(), -1))
      end
      row.addView(makeAction(actions[index]), LinearLayout.LayoutParams(0, dp(K.actionHeight), 1))
    end
    card.addView(row, LinearLayout.LayoutParams(-1, -2))
  else
    for index = 1, #actions do
      local line = View(current)
      line.setBackgroundColor(palette.separator)
      card.addView(line, LinearLayout.LayoutParams(-1, hairline()))
      card.addView(makeAction(actions[index]), LinearLayout.LayoutParams(-1, dp(K.actionHeight)))
    end
  end

  dialog.setContentView(card)
  local window = dialog.getWindow()
  if window then
    window.setBackgroundDrawable(ColorDrawable(0x00000000))
    window.addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
    window.setDimAmount(alphaValue(OP.overlay))
    window.setGravity(Gravity.CENTER)
    window.setLayout(dp(K.alertWidth), -2)
  end
  dialog.show()
  return dialog
end

function M.actionSheet(spec)
  spec = spec or {}
  local palette = colors()
  local current = activity
  local dialog = Dialog(current)
  dialog.requestWindowFeature(1)
  dialog.setCanceledOnTouchOutside(true)

  local root = LinearLayout(current)
  root.setOrientation(LinearLayout.VERTICAL)
  root.setPadding(dp(space(8)), dp(space(8)), dp(space(8)), dp(space(24)))

  local group = LinearLayout(current)
  group.setOrientation(LinearLayout.VERTICAL)
  group.setBackground(roundRect(palette.surface, R.sheet))
  group.setClipToOutline(true)

  if spec.title or spec.message then
    local head = LinearLayout(current)
    head.setOrientation(LinearLayout.VERTICAL)
    head.setPadding(dp(space(16)), dp(space(14)), dp(space(16)), dp(space(14)))
    if spec.title then
      local title = textView(spec.title, TY.footnote.size, palette.secondary, true)
      title.setGravity(Gravity.CENTER)
      head.addView(title)
    end
    if spec.message then
      local message = textView(spec.message, TY.footnote.size, palette.secondary, false)
      message.setGravity(Gravity.CENTER)
      message.setPadding(0, dp(space(4)), 0, 0)
      head.addView(message)
    end
    group.addView(head)
  end

  local actions = spec.actions or {}
  for index = 1, #actions do
    local action = actions[index]
    local line = View(current)
    line.setBackgroundColor(palette.separator)
    group.addView(line, LinearLayout.LayoutParams(-1, hairline()))
    local color = action.style == "destructive" and palette.danger or palette.accent
    local item = textView(action.title or "", TY.bodyLarge.size, color, false)
    item.setGravity(Gravity.CENTER)
    item.setBackground(ripple(0x00000000, 0, palette.press))
    item.setOnClickListener(View.OnClickListener{
      onClick = function()
        local keep = false
        if action.onClick then
          keep = action.onClick() == false
        end
        if not keep then
          dialog.dismiss()
        end
      end
    })
    group.addView(item, LinearLayout.LayoutParams(-1, dp(K.sheetItem)))
  end
  root.addView(group, LinearLayout.LayoutParams(-1, -2))

  local cancel = textView(spec.cancelText or "取消", TY.bodyLarge.size, palette.accent, true)
  cancel.setGravity(Gravity.CENTER)
  cancel.setBackground(ripple(palette.surface, R.sheet, palette.press))
  local cancelParams = LinearLayout.LayoutParams(-1, dp(K.sheetItem))
  cancelParams.topMargin = dp(space(8))
  root.addView(cancel, cancelParams)
  cancel.setOnClickListener(View.OnClickListener{
    onClick = function()
      dialog.dismiss()
    end
  })

  dialog.setContentView(root)
  local window = dialog.getWindow()
  if window then
    window.setBackgroundDrawable(ColorDrawable(0x00000000))
    window.addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
    window.setDimAmount(alphaValue(OP.overlay))
    window.setGravity(Gravity.BOTTOM)
    window.setLayout(-1, -2)
  end
  dialog.show()
  return dialog
end


-- ===== 快捷页面与表单 =====
-- 一行创建页面：content 里直接往 page.content 加组件，默认带入场动画。
function M.show(spec)
  spec = spec or {}
  local page = M.page(spec)
  if type(spec.content) == "function" then
    spec.content(page.content, page)
  elseif spec.content then
    page:add(spec.content)
  end
  page:show()
  if spec.animate ~= false then
    page:reveal(spec.animate)
  end
  return page
end

-- 快捷表单：字段用 fieldRow，返回输入框映射和读写方法。
function M.form(spec)
  spec = spec or {}
  local rows = {}
  local inputs = {}
  local fields = spec.fields or {}
  for index = 1, #fields do
    local item = M.fieldRow(fields[index])
    rows[#rows + 1] = item.view
    inputs[fields[index].name or index] = item.input
  end
  local view = M.group(spec.title or spec.header, rows, spec.footer)
  local form = {
    view = view,
    inputs = inputs,
  }
  function form.getValues()
    local values = {}
    for key, input in pairs(inputs) do
      values[key] = tostring(input.getText().toString())
    end
    return values
  end
  function form.setValues(values)
    for key, value in pairs(values or {}) do
      local input = inputs[key]
      if input then
        input.setText(tostring(value or ""))
      end
    end
    return form
  end
  function form.reset()
    for _, input in pairs(inputs) do
      input.setText("")
    end
    return form
  end
  return form
end

-- ===== 高效组件 =====
function M.chip(spec)
  if type(spec) == "string" then
    spec = { text = spec }
  end
  spec = spec or {}
  local palette = colors()
  local selected = spec.selected == true
  local fill = selected and (spec.color or palette.accent) or palette.fill
  local textColor = selected and palette.onAccent or palette.label

  local chip = textView(spec.text or "", spec.textSize or TY.subhead.size, textColor, true)
  chip.setGravity(Gravity.CENTER)
  chip.setPadding(dp(space(12)), dp(space(7)), dp(space(12)), dp(space(7)))
  chip.setMinHeight(dp(K.chipHeight))
  chip.setBackground(roundRect(parseColor(fill), R.chip))
  if spec.onClick then
    chip.setOnClickListener(View.OnClickListener{
      onClick = spec.onClick
    })
  end
  return chip
end

function M.chipGroup(spec)
  spec = spec or {}
  local palette = colors()
  local row = LinearLayout(activity)
  row.setOrientation(LinearLayout.HORIZONTAL)
  row.setGravity(Gravity.CENTER_VERTICAL)

  local chips = {}
  local items = spec.items or {}
  local selected = spec.selected or 1

  local function apply()
    for index = 1, #chips do
      local chip = chips[index]
      local active = index == selected
      chip.setTextColor(active and palette.onAccent or palette.label)
      chip.setBackground(roundRect(active and palette.accent or palette.fill, R.chip))
    end
  end

  for index = 1, #items do
    local item = items[index]
    if type(item) ~= "table" then
      item = { text = tostring(item) }
    end
    local chip = M.chip({ text = item.text or item.title or "", textSize = TY.footnote.size })
    local params = LinearLayout.LayoutParams(-2, -2)
    if index > 1 then
      params.leftMargin = dp(space(8))
    end
    row.addView(chip, params)
    chips[index] = chip
    chip.setOnClickListener(View.OnClickListener{
      onClick = function()
        selected = index
        apply()
        if spec.onChange then
          spec.onChange(index, item)
        end
      end
    })
  end
  apply()

  return {
    view = row,
    getSelected = function()
      return selected
    end,
    setSelected = function(index)
      selected = index
      apply()
    end,
  }
end

function M.checkRow(spec)
  spec = spec or {}
  local palette = colors()
  local checked = spec.checked == true

  local row = LinearLayout(activity)
  row.setOrientation(LinearLayout.HORIZONTAL)
  row.setGravity(Gravity.CENTER_VERTICAL)
  row.setMinimumHeight(dp(K.buttonHeight))
  row.setPadding(dp(space(16)), dp(space(7)), dp(space("buttonX")), dp(space(7)))
  row.setBackground(ripple(0x00000000, 0, palette.press))

  local textBox = LinearLayout(activity)
  textBox.setOrientation(LinearLayout.VERTICAL)
  row.addView(textBox, LinearLayout.LayoutParams(0, -2, 1))

  local title = textView(spec.title or "", TY.bodyCompact.size, palette.label, false)
  textBox.addView(title)
  if spec.subtitle then
    local subtitle = textView(spec.subtitle, TY.footnote.size, palette.secondary, false)
    subtitle.setPadding(0, dp(space(2)), 0, 0)
    textBox.addView(subtitle)
  end

  local mark = textView("", TY.subhead.size, palette.onAccent, true)
  mark.setGravity(Gravity.CENTER)
  row.addView(mark, LinearLayout.LayoutParams(dp(K.checkMark), dp(K.checkMark)))

  local function apply()
    mark.setText("")
    local checkId = checked and icons.drawable("check") or nil
    if checkId then
      mark.setCompoundDrawablesWithIntrinsicBounds(checkId, 0, 0, 0)
      pcall(function()
        local drawable = mark.getCompoundDrawables()[0]
        if drawable then
          icons.tintDrawable(drawable, palette.onAccent)
        end
      end)
    else
      mark.setCompoundDrawablesWithIntrinsicBounds(0, 0, 0, 0)
    end
    mark.setBackground(checked and roundRect(palette.accent, R.check) or shape(palette.transparent, palette.tertiary, R.check))
  end

  local function setChecked(value, notify)
    checked = value == true
    apply()
    if notify and spec.onChange then
      spec.onChange(checked)
    end
  end

  apply()
  row.setOnClickListener(View.OnClickListener{
    onClick = function()
      setChecked(not checked, true)
    end
  })

  return {
    view = row,
    isChecked = function()
      return checked
    end,
    setChecked = setChecked,
  }
end

function M.slider(spec)
  spec = spec or {}
  local palette = colors()
  local box = LinearLayout(activity)
  box.setOrientation(LinearLayout.VERTICAL)

  local header = LinearLayout(activity)
  header.setOrientation(LinearLayout.HORIZONTAL)
  header.setGravity(Gravity.CENTER_VERTICAL)
  local valueView = textView("", TY.footnote.size, palette.secondary, false)
  if spec.label then
    local label = textView(spec.label, TY.subhead.size, palette.label, false)
    header.addView(label, LinearLayout.LayoutParams(0, -2, 1))
    header.addView(valueView)
  else
    header.addView(valueView, LinearLayout.LayoutParams(-1, -2))
  end
  box.addView(header)

  local seek = SeekBar(activity)
  seek.setMax(spec.max or 100)
  seek.setProgress(spec.value or 0)
  pcall(function()
    seek.setProgressTintList(ColorStateList.valueOf(palette.accent))
    seek.setThumbTintList(ColorStateList.valueOf(palette.accent))
  end)

  local function format(value)
    if spec.format then
      return tostring(spec.format(value))
    end
    return tostring(value)
  end

  valueView.setText(format(seek.getProgress()))
  seek.setOnSeekBarChangeListener(SeekBar.OnSeekBarChangeListener{
    onProgressChanged = function(_, value, fromUser)
      valueView.setText(format(value))
      if spec.onChange then
        spec.onChange(value, fromUser)
      end
    end,
    onStartTrackingTouch = function()
    end,
    onStopTrackingTouch = function()
    end,
  })
  box.addView(seek, LinearLayout.LayoutParams(-1, -2))

  return {
    view = box,
    getValue = function()
      return seek.getProgress()
    end,
    setValue = function(value)
      seek.setProgress(value)
    end,
  }
end

function M.stepper(spec)
  spec = spec or {}
  local palette = colors()
  local minimum = spec.min or 0
  local maximum = spec.max or 99
  local step = spec.step or 1
  if step <= 0 then
    step = 1
  end
  local value = spec.value or minimum

  local box = LinearLayout(activity)
  box.setOrientation(LinearLayout.VERTICAL)
  if spec.label then
    local label = textView(spec.label, TY.footnote.size, palette.secondary, false)
    label.setPadding(dp(space(4)), dp(space(4)), dp(space(4)), dp(space(4)))
    box.addView(label)
  end

  local row = LinearLayout(activity)
  row.setOrientation(LinearLayout.HORIZONTAL)
  row.setGravity(Gravity.CENTER_VERTICAL)

  local function control(text)
    local view = textView(text, TY.action.size, palette.accent, false)
    view.setGravity(Gravity.CENTER)
    view.setBackground(roundRect(palette.fill, R.stepper))
    row.addView(view, LinearLayout.LayoutParams(dp(K.stepper), dp(K.stepper)))
    return view
  end

  local minus = control("−")
  local valueView = textView("", TY.body.size, palette.label, true)
  valueView.setGravity(Gravity.CENTER)
  row.addView(valueView, LinearLayout.LayoutParams(0, dp(K.stepper), 1))
  local plus = control("+")
  box.addView(row, LinearLayout.LayoutParams(-1, -2))

  local function apply(notify)
    valueView.setText(tostring(value))
    if notify and spec.onChange then
      spec.onChange(value)
    end
  end

  local function setValue(nextValue, notify)
    value = math.max(minimum, math.min(maximum, nextValue))
    apply(notify)
  end

  minus.setOnClickListener(View.OnClickListener{
    onClick = function()
      setValue(value - step, true)
    end,
  })
  plus.setOnClickListener(View.OnClickListener{
    onClick = function()
      setValue(value + step, true)
    end,
  })
  apply(false)

  return {
    view = box,
    getValue = function()
      return value
    end,
    setValue = setValue,
  }
end

function M.progress(spec)
  spec = spec or {}
  local palette = colors()
  local bar
  local ok, created = pcall(function()
    return ProgressBar(activity, nil, 16842872)
  end)
  if ok and created then
    bar = created
  else
    bar = ProgressBar(activity)
  end
  bar.setMax(spec.max or 100)
  bar.setProgress(spec.value or 0)
  if spec.indeterminate then
    bar.setIndeterminate(true)
  end
  pcall(function()
    bar.setProgressTintList(ColorStateList.valueOf(parseColor(spec.color or palette.accent)))
  end)

  local box = LinearLayout(activity)
  box.setOrientation(LinearLayout.VERTICAL)
  if spec.label then
    local label = textView(spec.label, TY.footnote.size, palette.secondary, false)
    label.setPadding(dp(space(4)), dp(space(4)), dp(space(4)), dp(space(2)))
    box.addView(label)
  end
  box.addView(bar, LinearLayout.LayoutParams(-1, -2))

  return {
    view = box,
    setProgress = function(value)
      bar.setProgress(value)
    end,
    getProgress = function()
      return bar.getProgress()
    end,
  }
end

function M.shimmer(view, spec)
  spec = spec or {}
  if type(view) == "table" and view.view and type(view.view) ~= "function" then
    view = view.view
  end
  local animator = ValueAnimator.ofFloat(float{alphaValue(OP.shimmerLow), alphaValue(OP.shimmerHigh)})
  animator.setDuration(timeValue(spec.duration or MO.shimmer, 900))
  animator.setRepeatCount(-1)
  animator.setRepeatMode(2)
  animator.addUpdateListener(ValueAnimator.AnimatorUpdateListener{
    onAnimationUpdate = function(animation)
      view.setAlpha(animation.getAnimatedValue())
    end,
  })
  animator.start()
  return animator
end

function M.skeleton(spec)
  spec = spec or {}
  local palette = colors()
  local box = LinearLayout(activity)
  box.setOrientation(LinearLayout.VERTICAL)
  box.setPadding(dp(space(16)), dp(space(16)), dp(space(16)), dp(space(16)))
  box.setBackground(roundRect(palette.surface, R.card))

  local lines = spec.lines or 3
  for index = 1, lines do
    local line = View(activity)
    line.setBackground(roundRect(palette.fill, R.skeleton))
    local width = index == lines and 0.55 or (index == 1 and 0.86 or 0.7)
    local params = LinearLayout.LayoutParams(-1, dp(space(index == 1 and 16 or 12)))
    if index > 1 then
      params.topMargin = dp(space(10))
    end
    if width < 1 then
      local holder = LinearLayout(activity)
      holder.setOrientation(LinearLayout.HORIZONTAL)
      holder.addView(line, LinearLayout.LayoutParams(0, dp(space(index == 1 and 16 or 12)), width))
      local rest = View(activity)
      holder.addView(rest, LinearLayout.LayoutParams(0, 1, 1 - width))
      box.addView(holder, params)
    else
      box.addView(line, params)
    end
  end

  local animator = M.shimmer(box, { duration = spec.duration or MO.shimmer })
  return {
    view = box,
    stop = function()
      pcall(function()
        animator.cancel()
      end)
      box.setAlpha(1)
    end,
  }
end

function M.banner(spec)
  spec = spec or {}
  local palette = colors()
  local card = LinearLayout(activity)
  card.setOrientation(LinearLayout.VERTICAL)
  card.setPadding(dp(space("buttonX")), dp(space(13)), dp(space("buttonX")), dp(space(13)))
  card.setBackground(roundRect(parseColor(spec.background or palette.accentSoft), R.banner))

  local header = LinearLayout(activity)
  header.setOrientation(LinearLayout.HORIZONTAL)
  header.setGravity(Gravity.CENTER_VERTICAL)
  card.addView(header)

  local bannerIcon = spec.icon or "info"
  local glyph
  if type(bannerIcon) == "string" and icons.has(bannerIcon) then
    local bg = parseColor(spec.color or palette.accent)
    glyph = icons.chip(bannerIcon, {
      size = K.bannerGlyph,
      iconSize = math.max(12, K.bannerGlyph - 8),
      background = bg,
      color = icons.contrast(bg),
      radius = R.glyph,
    })
    local iconParams = LinearLayout.LayoutParams(dp(K.bannerGlyph), dp(K.bannerGlyph))
    header.addView(glyph, iconParams)
  else
    glyph = textView(bannerIcon, TY.subhead.size, palette.onAccent, true)
    glyph.setGravity(Gravity.CENTER)
    glyph.setBackground(roundRect(parseColor(spec.color or palette.accent), R.glyph))
    header.addView(glyph, LinearLayout.LayoutParams(dp(K.bannerGlyph), dp(K.bannerGlyph)))
  end

  local title = textView(spec.title or "提示", TY.callout.size, palette.label, true)
  title.setPadding(dp(space(10)), 0, 0, 0)
  header.addView(title, LinearLayout.LayoutParams(0, -2, 1))

  if spec.message then
    local message = textView(spec.message, TY.footnote.size, palette.secondary, false)
    message.setPadding(dp(space(38)), dp(space(4)), 0, 0)
    card.addView(message)
  end

  if spec.action then
    local action = M.button({
      text = spec.action.title or "查看",
      style = "plain",
      textSize = 13,
      onClick = spec.action.onClick,
    })
    local params = LinearLayout.LayoutParams(-2, dp(space(44)))
    params.leftMargin = dp(space(38))
    params.topMargin = dp(space(4))
    card.addView(action, params)
  end
  return card
end

function M.stat(spec)
  spec = spec or {}
  local palette = colors()
  local card = LinearLayout(activity)
  card.setOrientation(LinearLayout.VERTICAL)
  card.setPadding(dp(space(14)), dp(space(14)), dp(space(14)), dp(space(14)))
  card.setBackground(roundRect(palette.surface, R.card))

  local value = textView(spec.value or "0", spec.valueSize or TY.stat.size, parseColor(spec.color or palette.label), true)
  value.setIncludeFontPadding(false)
  card.addView(value)

  local label = textView(spec.label or "", TY.footnote.size, palette.secondary, false)
  label.setPadding(0, dp(space(4)), 0, 0)
  card.addView(label)

  if spec.note then
    local note = textView(spec.note, TY.caption.size, spec.noteColor or palette.accent, true)
    note.setPadding(0, dp(space(6)), 0, 0)
    card.addView(note)
  end
  return card
end

function M.statRow(items, spec)
  spec = spec or {}
  local row = LinearLayout(activity)
  row.setOrientation(LinearLayout.HORIZONTAL)
  for index = 1, #(items or {}) do
    local params = LinearLayout.LayoutParams(0, -2, 1)
    if index > 1 then
      params.leftMargin = dp(space(spec.gap or 8))
    end
    row.addView(M.stat(items[index]), params)
  end
  return row
end

function M.fab(spec)
  if type(spec) == "string" then
    spec = { text = spec }
  end
  spec = spec or {}
  local palette = colors()
  local fab = textView(spec.text or "+", spec.textSize or TY.fab.size, palette.onAccent, true)
  fab.setGravity(Gravity.CENTER)
  fab.setBackground(roundRect(parseColor(spec.color or palette.accent), R.fab))
  fab.setMinWidth(dp(K.fab))
  fab.setMinHeight(dp(K.fab))
  fab.setElevation(dp(EL.fab))
  if spec.onClick then
    fab.setOnClickListener(View.OnClickListener{
      onClick = spec.onClick
    })
  end
  return fab
end

function M.toast(spec)
  if type(spec) == "string" then
    spec = { text = spec }
  end
  spec = spec or {}
  local palette = colors()
  local box = LinearLayout(activity)
  box.setPadding(dp(space(16)), dp(space(10)), dp(space(16)), dp(space(10)))
  box.setBackground(roundRect(palette.surface, R.toast))
  local text = textView(spec.text or "", TY.footnote.size, palette.label, false)
  box.addView(text)

  local toast = Toast.makeText(activity, "", spec.long and Toast.LENGTH_LONG or Toast.LENGTH_SHORT)
  toast.setView(box)
  toast.setGravity(Gravity.BOTTOM, 0, dp(space(spec.offset or 72)))
  toast.show()
  return toast
end

-- ===== 原子组件 =====
-- 原子组件只负责一件事，复合组件由这些原子继续组合。
-- 文本：统一字号、颜色、字重、对齐、行数、字距和内边距。
function M.text(spec)
  if type(spec) == "string" then
    spec = { text = spec }
  end
  spec = spec or {}
  local palette = colors()
  local typeToken = type(spec.type) == "string" and TY[spec.type] or nil
  local fontSize = spec.size or spec.textSize or (typeToken and typeToken.size) or TY.body.size
  local weight = numberValue(spec.weight, typeToken and typeToken.weight or 0)
  local bold
  if spec.bold ~= nil then
    bold = spec.bold == true
  else
    bold = weight >= 600
  end
  local view = textView(
    spec.text or spec.value or "",
    fontSize,
    parseColor(spec.color or palette.label),
    bold
  )
  if spec.mono then
    view.setTypeface(Typeface.MONOSPACE)
  end
  local tracking = spec.tracking
  if tracking == nil and typeToken then
    tracking = typeToken.tracking
  end
  if tracking then
    view.setLetterSpacing(numberValue(tracking, 0))
  end
  if spec.lines then
    view.setMaxLines(math.max(1, math.floor(numberValue(spec.lines, 1))))
  end
  if spec.ellipsize then
    view.setEllipsize(TextUtils.TruncateAt.END)
  end
  if spec.align == "center" then
    view.setGravity(Gravity.CENTER)
  elseif spec.align == "right" then
    view.setGravity(Gravity.RIGHT | Gravity.CENTER_VERTICAL)
  end
  if spec.padding then
    local padding = dp(space(spec.padding))
    view.setPadding(padding, padding, padding, padding)
  end
  if spec.includeFontPadding == false then
    view.setIncludeFontPadding(false)
  end
  if spec.onClick then
    view.setOnClickListener(View.OnClickListener{ onClick = spec.onClick })
  end
  return view
end

-- 图标：可以是字形，也可以是本地/网络图片；统一尺寸和圆角。
function M.icon(spec)
  if type(spec) == "string" then
    spec = { glyph = spec }
  end
  spec = spec or {}
  local palette = colors()
  local size = dimension(spec.size or TY.icon.size, TY.icon.size)
  if spec.src or spec.image then
    local image = M.image({
      src = spec.src or spec.image,
      width = size,
      height = size,
      scale = spec.scale or "contain",
      radius = spec.radius or "circle",
      circle = spec.circle ~= false,
      tint = spec.tint,
      alpha = spec.alpha,
      placeholder = spec.placeholder,
    })
    image.setMinimumWidth(dp(size))
    image.setMinimumHeight(dp(size))
    image.setLayoutParams(LinearLayout.LayoutParams(dp(size), dp(size)))
    if spec.onClick then
      image.setOnClickListener(View.OnClickListener{ onClick = spec.onClick })
    end
    return image
  end
  local iconName = spec.iconName or spec.icon
  if type(iconName) == "string" and icons.has(iconName) then
    local chip = spec.background or spec.bg
    local iconColor = spec.color or spec.tint
    if chip then
      local bg = parseColor(chip)
      local chipView = icons.chip(iconName, {
        size = size,
        iconSize = spec.glyphSize or math.max(12, math.floor(size * 0.62)),
        background = bg,
        color = iconColor or icons.contrast(bg),
        radius = spec.radius or size / 2,
        alpha = spec.alpha,
      })
      if spec.onClick then
        chipView.setOnClickListener(View.OnClickListener{ onClick = spec.onClick })
      end
      return chipView
    end
    local vector = icons.view(iconName, {
      size = size,
      color = iconColor or palette.label,
      alpha = spec.alpha,
    })
    vector.setMinimumWidth(dp(size))
    vector.setMinimumHeight(dp(size))
    vector.setLayoutParams(LinearLayout.LayoutParams(dp(size), dp(size)))
    if spec.onClick then
      vector.setOnClickListener(View.OnClickListener{ onClick = spec.onClick })
    end
    return vector
  end
  local chip = spec.background or spec.bg
  -- 带底色的图标本质是圆形容器，字形应比容器小一圈，否则会撑成竖长椭圆。
  local font = spec.glyphSize or (chip and math.max(10, math.floor(size * 0.68)) or size)
  local view = textView(spec.glyph or spec.text or "●", font, parseColor(spec.color or palette.label), spec.bold == true)
  view.setGravity(Gravity.CENTER)
  view.setIncludeFontPadding(false)
  if chip then
    view.setBackground(roundRect(parseColor(chip), spec.radius or size / 2))
  end
  if spec.padding then
    local padding = dp(space(spec.padding))
    view.setPadding(padding, padding, padding, padding)
  end
  if spec.alpha then
    view.setAlpha(alphaValue(spec.alpha))
  end
  local extent = dp(size)
  pcall(function()
    view.setMinimumWidth(extent)
    view.setMinimumHeight(extent)
  end)
  -- hstack 等容器会用 WRAP_CONTENT 重新添加子 View，必须把测量尺寸也锁成正方形。
  pcall(function()
    view.setMaxWidth(extent)
    view.setMaxHeight(extent)
  end)
  view.setLayoutParams(LinearLayout.LayoutParams(extent, extent))
  if spec.onClick then
    view.setOnClickListener(View.OnClickListener{ onClick = spec.onClick })
  end
  return view
end

-- 表面：带底色、描边、圆角、内边距和可选点击反馈的容器。
function M.surface(spec, content)
  spec = spec or {}
  local palette = colors()
  local box = LinearLayout(activity)
  box.setOrientation(spec.direction == "row" and LinearLayout.HORIZONTAL or LinearLayout.VERTICAL)
  local fill = parseColor(spec.background or palette.surface)
  local radius = spec.radius or R.card
  box.setBackground(shape(fill, spec.stroke and parseColor(spec.stroke), radius))
  if spec.clip ~= false then
    box.setClipToOutline(true)
  end
  local padding = spec.padding or S.card
  local paddingValue = dp(space(padding))
  box.setPadding(paddingValue, paddingValue, paddingValue, paddingValue)
  local elevation = spec.elevation
  if elevation == nil then
    elevation = EL.card
  end
  if elevation ~= false then
    box.setElevation(dp(dimension(elevation, EL.card)))
  end
  if spec.onClick then
    box.setOnClickListener(View.OnClickListener{ onClick = spec.onClick })
  end
  if content then
    if type(content) == "function" then
      content(box, box)
    else
      box.addView(content, LinearLayout.LayoutParams(-1, -2))
    end
  end
  return box
end

-- 栈：按行/列排列子 View，并统一处理 gap。
function M.stack(spec, content)
  spec = spec or {}
  local horizontal = spec.direction == "row" or spec.orientation == "horizontal"
  local box = LinearLayout(activity)
  box.setOrientation(horizontal and LinearLayout.HORIZONTAL or LinearLayout.VERTICAL)
  if spec.align == "center" then
    box.setGravity(horizontal and Gravity.CENTER_VERTICAL or Gravity.CENTER_HORIZONTAL)
  elseif spec.align == "end" then
    box.setGravity(horizontal and Gravity.RIGHT or Gravity.BOTTOM)
  end
  if spec.padding then
    local padding = dp(space(spec.padding))
    box.setPadding(padding, padding, padding, padding)
  end
  local gap = dp(space(spec.gap or S.gap))
  local function add(view)
    if not view then
      return
    end
    local params
    if horizontal then
      params = LinearLayout.LayoutParams(spec.fill and 0 or -2, -2, spec.fill and 1 or 0)
      if box.getChildCount() > 0 then
        params.leftMargin = gap
      end
    else
      params = LinearLayout.LayoutParams(-1, -2)
      if box.getChildCount() > 0 then
        params.topMargin = gap
      end
    end
    box.addView(view, params)
  end
  if spec.items then
    for index = 1, #spec.items do
      add(spec.items[index])
    end
  end
  if content then
    content(add, box)
  end
  return box
end

function M.vstack(spec, content)
  spec = spec or {}
  spec.direction = "column"
  return M.stack(spec, content)
end

function M.hstack(spec, content)
  spec = spec or {}
  spec.direction = "row"
  return M.stack(spec, content)
end

-- 网格：把一组 View 按固定列数摆放，最后一行自动留白。
function M.grid(spec)
  spec = spec or {}
  local items = spec.items or {}
  local columns = math.max(1, math.floor(numberValue(spec.columns, 2)))
  local gap = dp(space(spec.gap or S.gap))
  local root = LinearLayout(activity)
  root.setOrientation(LinearLayout.VERTICAL)
  local row
  for index = 1, #items do
    local column = (index - 1) % columns
    if column == 0 then
      row = LinearLayout(activity)
      row.setOrientation(LinearLayout.HORIZONTAL)
      local params = LinearLayout.LayoutParams(-1, -2)
      if root.getChildCount() > 0 then
        params.topMargin = gap
      end
      root.addView(row, params)
    end
    local params = LinearLayout.LayoutParams(0, -2, 1)
    if column > 0 then
      params.leftMargin = gap
    end
    row.addView(items[index], params)
  end
  return root
end

-- 居中容器：快速把单个 View 或自定义内容放到页面中间。
function M.center(spec, content)
  spec = spec or {}
  local frame = FrameLayout(activity)
  if spec.background then
    frame.setBackground(shape(parseColor(spec.background), nil, spec.radius or R.card))
  end
  if spec.padding then
    local padding = dp(space(spec.padding))
    frame.setPadding(padding, padding, padding, padding)
  end
  if content then
    if type(content) == "function" then
      content(frame, frame)
    else
      frame.addView(content, FrameLayout.LayoutParams(-2, -2, Gravity.CENTER))
    end
  end
  return frame
end

-- 输入原子：无标题、无帮助文本的裸输入框。
function M.input(spec)
  spec = spec or {}
  local palette = colors()
  local input = EditText(activity)
  configureInput(input, spec)
  local padding = dp(space(spec.padding or S.row))
  input.setPadding(padding, padding, padding, padding)
  if spec.background ~= false then
    input.setBackground(roundRect(parseColor(spec.background or palette.surface), spec.radius or R.input))
  end
  input.setMinimumHeight(dp(space(spec.height or K.inputHeight)))
  return input
end

-- 表单标签与帮助文本。
function M.label(spec)
  if type(spec) == "string" then
    spec = { text = spec }
  end
  spec = spec or {}
  local text = spec.text or spec.label or ""
  if spec.required then
    text = text .. " *"
  end
  local view = M.text({
    text = text,
    type = spec.type or "footnote",
    color = spec.color or colors().secondary,
    bold = spec.bold == true,
  })
  view.setPadding(dp(space("labelX")), dp(space("labelY")), dp(space("labelX")), dp(space("labelY")))
  return view
end

function M.helper(spec)
  if type(spec) == "string" then
    spec = { text = spec }
  end
  spec = spec or {}
  local palette = colors()
  local view = M.text({
    text = spec.text or spec.helper or "",
    type = spec.type or "footnote",
    color = spec.error and palette.danger or (spec.color or palette.secondary),
  })
  view.setPadding(dp(space("helperX")), dp(space("helperTop")), dp(space("helperX")), dp(space(0)))
  return view
end

-- 选择原子：勾选标记、复选框、单选标记。
local function paintCheckMark(mark, checked, palette)
  mark.setText("")
  local id = checked and icons.drawable("check") or nil
  if id then
    mark.setCompoundDrawablesWithIntrinsicBounds(id, 0, 0, 0)
    pcall(function()
      local drawables = mark.getCompoundDrawables()
      local drawable = drawables and drawables[0]
      if drawable then
        icons.tintDrawable(drawable, palette.onAccent)
      end
    end)
  else
    mark.setCompoundDrawablesWithIntrinsicBounds(0, 0, 0, 0)
  end
  if checked then
    mark.setBackground(roundRect(palette.accent, R.check))
  else
    mark.setBackground(shape(palette.transparent, palette.tertiary, R.check))
  end
end

function M.checkMark(spec)
  spec = spec or {}
  local palette = colors()
  local checked = spec.checked == true
  local size = dimension(spec.size or K.checkMark, K.checkMark)
  local mark = textView("", TY.callout.size, checked and palette.onAccent or palette.tertiary, true)
  mark.setGravity(Gravity.CENTER)
  mark.setIncludeFontPadding(false)
  paintCheckMark(mark, checked, palette)
  local extent = dp(size)
  pcall(function()
    mark.setMinimumWidth(extent)
    mark.setMinimumHeight(extent)
  end)
  pcall(function()
    mark.setMaxWidth(extent)
    mark.setMaxHeight(extent)
  end)
  mark.setLayoutParams(LinearLayout.LayoutParams(extent, extent))
  if spec.onClick then
    mark.setOnClickListener(View.OnClickListener{ onClick = spec.onClick })
  end
  return mark
end

function M.checkbox(spec)
  spec = spec or {}
  local palette = colors()
  local checked = spec.checked == true or spec.value == true
  local row = LinearLayout(activity)
  row.setOrientation(LinearLayout.HORIZONTAL)
  row.setGravity(Gravity.CENTER_VERTICAL)
  row.setPadding(dp(space("checkboxX")), dp(space("checkboxY")), dp(space("checkboxX")), dp(space("checkboxY")))
  local mark = M.checkMark({ checked = checked, size = spec.size })
  row.addView(mark)
  local label = M.text({
    text = spec.text or spec.label or "",
    type = spec.type or "body",
    color = spec.color or palette.label,
  })
  label.setPadding(dp(space("checkboxGap")), 0, 0, 0)
  row.addView(label, LinearLayout.LayoutParams(0, -2, 1))
  local function apply(value)
    checked = value
    paintCheckMark(mark, checked, palette)
    if spec.onChange then
      spec.onChange(checked)
    end
  end
  row.setOnClickListener(View.OnClickListener{
    onClick = function()
      if not spec.disabled then
        apply(not checked)
      end
    end,
  })
  if spec.disabled then
    row.setAlpha(alphaValue(OP.disabled))
  end
  return row
end

function M.radioMark(spec)
  spec = spec or {}
  local palette = colors()
  local checked = spec.checked == true
  local size = dimension(spec.size or TY.body.size, TY.body.size)
  local mark = icons.view(checked and "radio-checked" or "radio", {
    size = size,
    color = checked and (spec.color and parseColor(spec.color) or palette.accent) or palette.tertiary,
  })
  mark.setLayoutParams(LinearLayout.LayoutParams(dp(size), dp(size)))
  if spec.onClick then
    mark.setOnClickListener(View.OnClickListener{ onClick = spec.onClick })
  end
  return mark
end

M.radio = M.radioMark

-- 状态点：成功、警告、危险等状态的最小视觉单元。
function M.statusDot(spec)
  spec = spec or {}
  local palette = colors()
  local size = dimension(spec.size or K.statusDot, K.statusDot)
  local dot = View(activity)
  dot.setBackground(roundRect(parseColor(spec.color or palette.success), size / 2))
  local extent = dp(size)
  dot.setMinimumWidth(extent)
  dot.setMinimumHeight(extent)
  dot.setLayoutParams(LinearLayout.LayoutParams(extent, extent))
  if spec.alpha then
    dot.setAlpha(alphaValue(spec.alpha))
  end
  return dot
end

-- 底部标签原子；tabBar 可以用它组合自定义标签栏。
function M.tabItem(spec)
  spec = spec or {}
  local palette = colors()
  local selected = spec.selected == true
  local color = selected and palette.accent or palette.secondary
  local item = LinearLayout(activity)
  item.setOrientation(LinearLayout.VERTICAL)
  item.setGravity(Gravity.CENTER)
  item.setMinimumWidth(dp(space(56)))
  item.setMinimumHeight(dp(K.tabHeight))
  item.setPadding(dp(space(0)), dp(space("tabTop")), dp(space(0)), dp(space("tabBottom")))
  item.setBackground(ripple(palette.transparent, 0, palette.press))

  local iconSize = dimension(spec.iconSize or TY.icon.size, TY.icon.size)
  local holder = FrameLayout(activity)
  local holderParams = LinearLayout.LayoutParams(dp(iconSize), dp(iconSize))
  holder.setLayoutParams(holderParams)
  local iconView
  if spec.src or spec.image then
    iconView = M.icon({
      src = spec.src or spec.image,
      size = iconSize,
      tint = color,
      scale = "contain",
      circle = false,
    })
  elseif type(spec.glyph or spec.icon) == "string" and icons.has(spec.glyph or spec.icon) then
    iconView = icons.view(spec.glyph or spec.icon, {
      size = iconSize,
      color = color,
    })
  else
    local glyphText = spec.glyph or spec.icon or "●"
    if type(glyphText) == "userdata" then
      iconView = glyphText
    else
      -- 字形图标统一放进固定方框；信封等字形视觉偏小，单独补一点字号。
      local glyphSize = spec.glyphSize or iconSize
      if glyphText == "✉" or glyphText == "✉️" then
        glyphSize = glyphSize * 1.22
      elseif glyphText == "⌂" then
        glyphSize = glyphSize * 0.94
      end
      iconView = textView(glyphText, glyphSize, color, false)
      iconView.setGravity(Gravity.CENTER)
      iconView.setIncludeFontPadding(false)
    end
  end
  holder.addView(iconView, FrameLayout.LayoutParams(-1, -1))
  item.addView(holder, holderParams)

  local title = textView(spec.title or spec.text or "", TY.caption.size, color, false)
  title.setGravity(Gravity.CENTER)
  title.setIncludeFontPadding(false)
  title.setPadding(0, dp(space("tabGap")), 0, 0)
  title.setLetterSpacing(numberValue(TY.caption.tracking, 0))
  item.addView(title)
  if spec.onClick then
    item.setOnClickListener(View.OnClickListener{ onClick = spec.onClick })
  end
  return item
end

-- 数据单元格原子：表格、详情网格和列表都可以复用。
function M.cell(spec)
  if type(spec) == "string" then
    spec = { text = spec }
  end
  spec = spec or {}
  local palette = colors()
  local header = spec.header == true
  local align = spec.align or "left"
  local view = M.text({
    text = spec.text or spec.value or "",
    type = header and "footnote" or (spec.type or "subhead"),
    color = spec.color or (header and palette.secondary or palette.label),
    bold = header,
    align = align,
    lines = spec.lines or 2,
    ellipsize = true,
  })
  view.setPadding(dp(space(spec.padding or S.gap)), dp(space(S.tight)), dp(space(spec.padding or S.gap)), dp(space(S.tight)))
  if spec.width then
    view.setMinimumWidth(dp(space(spec.width)))
  end
  return view
end

-- 键值行原子：keyValue 之外的详情页也可以直接使用。
function M.kvRow(spec)
  spec = spec or {}
  local palette = colors()
  local row = LinearLayout(activity)
  row.setOrientation(LinearLayout.HORIZONTAL)
  row.setGravity(Gravity.CENTER_VERTICAL)
  row.setPadding(dp(space("kvX")), dp(space("kvY")), dp(space("kvX")), dp(space("kvY")))
  local label = M.text({ text = spec.label or spec.key or "", type = "subhead", color = palette.secondary })
  row.addView(label, LinearLayout.LayoutParams(0, -2, 1))
  if type(spec.value) == "userdata" then
    row.addView(spec.value, LinearLayout.LayoutParams(0, -2, 1.5))
  else
    local value = M.text({
      text = tostring(spec.value or ""),
      type = "subhead",
      color = spec.color or palette.label,
      align = "right",
    })
    row.addView(value, LinearLayout.LayoutParams(0, -2, 1.5))
  end
  return row
end

-- 动效原子：给复合组件提供更短的调用入口。
local function animatePreset(view, spec, preset)
  local options = spec or {}
  options.preset = options.preset or preset
  return M.animate(view, options)
end

function M.fadeIn(view, spec)
  return animatePreset(view, spec, "fade")
end

function M.slideIn(view, spec)
  return animatePreset(view, spec, "up")
end

function M.scaleIn(view, spec)
  return animatePreset(view, spec, "scale")
end

-- ===== 选择与数据展示 =====
-- 独立开关；带标题的开关行可以直接用 M.row({ toggle = ... })。
function M.switch(spec)
  if type(spec) == "boolean" then
    spec = { value = spec }
  end
  spec = spec or {}
  local palette = colors()
  local switchView
  local ok = pcall(function()
    local IosSwitch = luajava.bindClass("com.mini.luaxplus.ui.IosSwitch")
    switchView = luajava.new(IosSwitch, activity)
  end)
  if not ok or not switchView then
    switchView = Switch(activity)
    pcall(function()
      switchView.setShowText(false)
    end)
  else
    pcall(function()
      switchView.setTrackColors(palette.fill, palette.success)
    end)
  end
  switchView.setChecked(spec.value == true or spec.checked == true)
  local listener = spec.onChange or spec.onToggle
  switchView.setOnCheckedChangeListener(CompoundButton.OnCheckedChangeListener{
    onCheckedChanged = function(button, state)
      spec.value = state
      if listener then
        listener(state)
      end
    end
  })
  if spec.disabled then
    switchView.setEnabled(false)
    switchView.setAlpha(alphaValue(OP.disabled))
  end
  return switchView
end

function M.switchRow(spec)
  spec = spec or {}
  if spec.toggle == nil then
    spec.toggle = spec.value == true or spec.checked == true
  end
  return M.row(spec)
end

-- 单选组：items 支持字符串或 { title, subtitle, value }。
function M.radioGroup(spec)
  spec = spec or {}
  local palette = colors()
  local items = spec.items or {}
  local card = LinearLayout(activity)
  card.setOrientation(LinearLayout.VERTICAL)
  card.setBackground(roundRect(palette.surface, R.card))
  card.setClipToOutline(true)

  local selected = spec.selected
  if selected == nil then
    selected = spec.value
  end
  if type(selected) == "string" then
    for index = 1, #items do
      local item = items[index]
      if type(item) == "table" and tostring(item.value or "") == selected then
        selected = index
        break
      end
    end
  end
  selected = math.floor(numberValue(selected, 1))
  if selected < 1 or selected > #items then
    selected = 1
  end

  local indicators = {}
  local function apply()
    for index = 1, #indicators do
      local active = index == selected
      pcall(function()
        indicators[index].setImageResource(icons.drawable(active and "radio-checked" or "radio"))
        indicators[index].setColorFilter(active and palette.accent or palette.tertiary)
      end)
    end
  end

  local function choose(index)
    if spec.disabled then
      return
    end
    selected = index
    apply()
    if spec.onChange then
      spec.onChange(items[index], index)
    end
  end

  for index = 1, #items do
    local item = items[index]
    if type(item) ~= "table" then
      item = { title = tostring(item) }
    end
    if index > 1 then
      local line, params = separatorView(16)
      card.addView(line, params)
    end
    local indicator = icons.view("radio", { size = 20, color = palette.tertiary })
    indicator.setPadding(dp(space(6)), 0, 0, 0)
    indicators[index] = indicator
    local row = M.row({
      title = item.title or item.text or "",
      subtitle = item.subtitle,
      accessory = indicator,
      chevron = false,
      height = spec.height,
      onClick = function()
        choose(index)
      end,
    })
    card.addView(row, LinearLayout.LayoutParams(-1, -2))
  end
  apply()
  return card
end

-- 星级评分；value 为 1..max，readonly 时只展示。
function M.rating(spec)
  spec = spec or {}
  local palette = colors()
  local max = math.floor(numberValue(spec.max, 5))
  if max < 1 then
    max = 5
  end
  local value = math.floor(numberValue(spec.value, 0))
  value = math.max(0, math.min(max, value))
  local size = dimension(spec.size or TY.action.size, TY.action.size)
  local activeColor = parseColor(spec.color or palette.warning)
  local row = LinearLayout(activity)
  row.setOrientation(LinearLayout.HORIZONTAL)
  row.setGravity(Gravity.CENTER_VERTICAL)
  local stars = {}

  local function apply()
    for index = 1, #stars do
      local active = index <= value
      stars[index].setText(active and "★" or "☆")
      stars[index].setTextColor(active and activeColor or palette.tertiary)
    end
  end

  for index = 1, max do
    local star = textView("☆", size, palette.tertiary, false)
    star.setGravity(Gravity.CENTER)
    star.setPadding(dp(space(2)), dp(space(2)), dp(space(2)), dp(space(2)))
    stars[index] = star
    if not spec.readonly and not spec.disabled then
      star.setOnClickListener(View.OnClickListener{
        onClick = function()
          value = index
          apply()
          if spec.onChange then
            spec.onChange(value)
          end
        end
      })
    end
    row.addView(star)
  end
  apply()
  if spec.disabled then
    row.setAlpha(alphaValue(OP.disabled))
  end
  return row
end

-- 下拉选择：用底部动作菜单展示 options，避免引入第二套弹窗样式。
function M.select(spec)
  spec = spec or {}
  local palette = colors()
  local options = spec.options or {}
  local function labelOf(option)
    if type(option) == "table" then
      return tostring(option.title or option.text or option.label or option.value or "")
    end
    return tostring(option or "")
  end
  local selected = spec.selected
  if selected == nil then
    selected = spec.value or 1
  end
  if type(selected) == "string" then
    for index = 1, #options do
      local option = options[index]
      local value = type(option) == "table" and option.value or option
      if tostring(value) == selected then
        selected = index
        break
      end
    end
  end
  selected = math.floor(numberValue(selected, 1))
  if selected < 1 or selected > #options then
    selected = 1
  end
  local current = options[selected]
  local valueView = textView(
    current and labelOf(current) or (spec.placeholder or "请选择"),
    TY.callout.size,
    current and palette.label or palette.tertiary,
    false
  )
  valueView.setPadding(dp(space(8)), 0, dp(space(2)), 0)
  local row
  row = M.row({
    title = spec.title or "选项",
    subtitle = spec.subtitle,
    accessory = valueView,
    chevron = false,
    height = spec.height,
    onClick = function()
      if #options == 0 then
        return
      end
      local actions = {}
      for index = 1, #options do
        local option = options[index]
        actions[index] = {
          title = (index == selected and "✓ " or "") .. labelOf(option),
          onClick = function()
            selected = index
            valueView.setText(labelOf(option))
            valueView.setTextColor(palette.label)
            if spec.onChange then
              spec.onChange(option, index)
            end
          end,
        }
      end
      M.actionSheet({ title = spec.title, actions = actions })
    end,
  })
  return row
end

-- 键值说明列表；value 可以是字符串，也可以直接放一个 View。
function M.keyValue(spec)
  spec = spec or {}
  local palette = colors()
  local card = LinearLayout(activity)
  card.setOrientation(LinearLayout.VERTICAL)
  card.setBackground(roundRect(palette.surface, R.card))
  card.setClipToOutline(true)

  if spec.title then
    local title = textView(spec.title, TY.footnote.size, palette.secondary, true)
    title.setPadding(dp(space(16)), dp(space(12)), dp(space(16)), dp(space(6)))
    card.addView(title)
  end

  local items = spec.items or {}
  for index = 1, #items do
    local item = items[index]
    if type(item) ~= "table" then
      item = { label = tostring(item), value = "" }
    end
    if index > 1 then
      local line, params = separatorView(16)
      card.addView(line, params)
    end
    local row = LinearLayout(activity)
    row.setOrientation(LinearLayout.HORIZONTAL)
    row.setGravity(Gravity.CENTER_VERTICAL)
    row.setPadding(dp(space(16)), dp(space(10)), dp(space(16)), dp(space(10)))
    local label = textView(item.label or item.key or "", TY.subhead.size, palette.secondary, false)
    row.addView(label, LinearLayout.LayoutParams(0, -2, 1))
    if type(item.value) == "userdata" then
      row.addView(item.value, LinearLayout.LayoutParams(0, -2, 1.5))
    else
      local value = textView(tostring(item.value or ""), TY.subhead.size, parseColor(item.color or palette.label), false)
      value.setGravity(Gravity.RIGHT | Gravity.CENTER_VERTICAL)
      row.addView(value, LinearLayout.LayoutParams(0, -2, 1.5))
    end
    card.addView(row, LinearLayout.LayoutParams(-1, -2))
  end

  if spec.footer then
    local footer = textView(spec.footer, TY.footnote.size, palette.secondary, false)
    footer.setPadding(dp(space(16)), dp(space(8)), dp(space(16)), dp(space(12)))
    card.addView(footer)
  end
  return card
end

M.descriptionList = M.keyValue

-- 表格：columns 支持 { title, key, width, weight, align }，rows 支持数组或字段映射。
function M.table(spec)
  spec = spec or {}
  local palette = colors()
  local columns = spec.columns or {}
  local rows = spec.rows or {}
  local card = LinearLayout(activity)
  card.setOrientation(LinearLayout.VERTICAL)
  card.setBackground(roundRect(palette.surface, R.card))
  card.setClipToOutline(true)
  if type(columns) == "string" then
    columns = { columns }
  end
  for index = 1, #columns do
    if type(columns[index]) ~= "table" then
      columns[index] = { title = tostring(columns[index]) }
    end
  end

  local function makeCell(text, column, header)
    local cell = textView(tostring(text or ""), header and TY.footnote.size or TY.subhead.size,
      header and palette.secondary or palette.label, header)
    cell.setPadding(dp(space(8)), dp(space(8)), dp(space(8)), dp(space(8)))
    cell.setMaxLines(2)
    cell.setEllipsize(TextUtils.TruncateAt.END)
    local gravity = Gravity.CENTER_VERTICAL
    if column.align == "right" then
      gravity = Gravity.RIGHT | Gravity.CENTER_VERTICAL
    elseif column.align == "center" then
      gravity = Gravity.CENTER
    end
    cell.setGravity(gravity)
    local width = column.width and dp(space(column.width)) or 0
    local params = LinearLayout.LayoutParams(width, -2, width == 0 and (column.weight or 1) or 0)
    return cell, params
  end

  local header = LinearLayout(activity)
  header.setOrientation(LinearLayout.HORIZONTAL)
  header.setBackgroundColor(palette.fill)
  for index = 1, #columns do
    local column = columns[index]
    local cell, params = makeCell(column.title or column.key or "", column, true)
    header.addView(cell, params)
  end
  card.addView(header, LinearLayout.LayoutParams(-1, -2))

  for rowIndex = 1, #rows do
    local data = rows[rowIndex]
    if type(data) ~= "table" then
      data = { data }
    end
    local row = LinearLayout(activity)
    row.setOrientation(LinearLayout.HORIZONTAL)
    if spec.striped and rowIndex % 2 == 0 then
      row.setBackgroundColor(palette.bg)
    end
    for index = 1, #columns do
      local column = columns[index]
      local value = data[column.key or index]
      local cell, params = makeCell(value, column, false)
      row.addView(cell, params)
    end
    if spec.onRowClick then
      row.setOnClickListener(View.OnClickListener{
        onClick = function()
          spec.onRowClick(data, rowIndex)
        end
      })
    end
    card.addView(row, LinearLayout.LayoutParams(-1, -2))
    if rowIndex < #rows then
      local line, params = separatorView(0)
      card.addView(line, params)
    end
  end

  if #rows == 0 then
    local empty = textView(spec.empty or "暂无数据", TY.subhead.size, palette.tertiary, false)
    empty.setGravity(Gravity.CENTER)
    empty.setPadding(dp(space(16)), dp(space(20)), dp(space(16)), dp(space(20)))
    card.addView(empty, LinearLayout.LayoutParams(-1, -2))
  end
  return card
end

-- 竖向时间线；items 支持 { title, time, description, active, color }。
function M.timeline(spec)
  spec = spec or {}
  local palette = colors()
  local root = LinearLayout(activity)
  root.setOrientation(LinearLayout.VERTICAL)
  local items = spec.items or {}
  for index = 1, #items do
    local item = items[index]
    if type(item) ~= "table" then
      item = { title = tostring(item) }
    end
    local row = LinearLayout(activity)
    row.setOrientation(LinearLayout.HORIZONTAL)
    row.setMinimumHeight(dp(space(52)))
    row.setPadding(0, 0, 0, dp(space(2)))

    local rail = FrameLayout(activity)
    row.addView(rail, LinearLayout.LayoutParams(dp(space(24)), -1))
    if index < #items then
      local line = View(activity)
      line.setBackgroundColor(palette.separator)
      local lineParams = FrameLayout.LayoutParams(hairline(), -1)
      lineParams.gravity = Gravity.CENTER_HORIZONTAL
      lineParams.topMargin = dp(space(16))
      rail.addView(line, lineParams)
    end
    local dot = View(activity)
    dot.setBackground(roundRect(parseColor(item.color or (item.active and palette.accent) or palette.tertiary), 5))
    local dotParams = FrameLayout.LayoutParams(dp(space(10)), dp(space(10)))
    dotParams.gravity = Gravity.TOP | Gravity.CENTER_HORIZONTAL
    dotParams.topMargin = dp(space(5))
    rail.addView(dot, dotParams)

    local content = LinearLayout(activity)
    content.setOrientation(LinearLayout.VERTICAL)
    row.addView(content, LinearLayout.LayoutParams(0, -2, 1))
    local head = LinearLayout(activity)
    head.setOrientation(LinearLayout.HORIZONTAL)
    head.setGravity(Gravity.CENTER_VERTICAL)
    local title = textView(item.title or "", TY.body.size, palette.label, item.active == true)
    head.addView(title, LinearLayout.LayoutParams(0, -2, 1))
    if item.time then
      local time = textView(item.time, TY.caption.size, palette.secondary, false)
      time.setGravity(Gravity.RIGHT)
      head.addView(time)
    end
    content.addView(head)
    if item.description then
      local description = textView(item.description, TY.footnote.size, palette.secondary, false)
      description.setPadding(0, dp(space(4)), 0, 0)
      content.addView(description)
    end
    root.addView(row, LinearLayout.LayoutParams(-1, -2))
  end
  return root
end

-- 折叠容器；header 点击展开/收起，content 支持函数或 View。
function M.accordion(spec)
  spec = spec or {}
  local palette = colors()
  local card = LinearLayout(activity)
  card.setOrientation(LinearLayout.VERTICAL)
  card.setBackground(roundRect(palette.surface, R.card))
  card.setClipToOutline(true)
  local expanded = spec.expanded ~= false

  local header = LinearLayout(activity)
  header.setOrientation(LinearLayout.HORIZONTAL)
  header.setGravity(Gravity.CENTER_VERTICAL)
  header.setPadding(dp(space(16)), dp(space(13)), dp(space(16)), dp(space(13)))
  header.setBackground(ripple(0x00000000, 0, palette.press))
  local textBox = LinearLayout(activity)
  textBox.setOrientation(LinearLayout.VERTICAL)
  header.addView(textBox, LinearLayout.LayoutParams(0, -2, 1))
  local title = textView(spec.title or "详情", TY.body.size, palette.label, true)
  textBox.addView(title)
  if spec.subtitle then
    local subtitle = textView(spec.subtitle, TY.footnote.size, palette.secondary, false)
    subtitle.setPadding(0, dp(space(3)), 0, 0)
    textBox.addView(subtitle)
  end
  local chevron = textView("⌃", TY.bodyLarge.size, palette.tertiary, false)
  chevron.setPadding(dp(space(8)), 0, 0, 0)
  header.addView(chevron)

  local body = LinearLayout(activity)
  body.setOrientation(LinearLayout.VERTICAL)
  body.setPadding(dp(space(16)), 0, dp(space(16)), dp(space(16)))
  if spec.content then
    if type(spec.content) == "function" then
      spec.content(body, card)
    else
      body.addView(spec.content, LinearLayout.LayoutParams(-1, -2))
    end
  end

  local function apply()
    body.setVisibility(expanded and View.VISIBLE or View.GONE)
    chevron.setText(expanded and "⌄" or "⌃")
  end
  header.setOnClickListener(View.OnClickListener{
    onClick = function()
      if spec.disabled then
        return
      end
      expanded = not expanded
      apply()
      if spec.onToggle then
        spec.onToggle(expanded)
      end
    end
  })
  card.addView(header, LinearLayout.LayoutParams(-1, -2))
  card.addView(body, LinearLayout.LayoutParams(-1, -2))
  apply()
  if spec.disabled then
    card.setAlpha(alphaValue(OP.disabled))
  end
  return card
end

-- 头像组：重叠展示，超出 max 时显示 +N。
function M.avatarGroup(spec)
  spec = spec or {}
  local palette = colors()
  local names = spec.names or spec.items or {}
  local size = dimension(spec.size or K.avatarGroup, K.avatarGroup)
  local max = math.floor(numberValue(spec.max, #names))
  local row = LinearLayout(activity)
  row.setOrientation(LinearLayout.HORIZONTAL)
  row.setGravity(Gravity.CENTER_VERTICAL)
  local count = math.min(#names, max)
  local overlap = dimension(spec.overlap or (size / 6), size / 6)
  for index = 1, count do
    local avatar = M.avatar(names[index], spec.color, size)
    local params = LinearLayout.LayoutParams(dp(size), dp(size))
    if index > 1 then
      params.leftMargin = -dp(overlap)
    end
    avatar.setLayoutParams(params)
    row.addView(avatar)
  end
  if #names > count then
    local more = textView("+" .. tostring(#names - count), TY.caption.size, palette.secondary, true)
    more.setGravity(Gravity.CENTER)
    more.setIncludeFontPadding(false)
    more.setBackground(roundRect(palette.fill, size / 2))
    local extent = dp(size)
    pcall(function()
      more.setMinimumWidth(extent)
      more.setMinimumHeight(extent)
    end)
    pcall(function()
      more.setMaxWidth(extent)
      more.setMaxHeight(extent)
    end)
    local params = LinearLayout.LayoutParams(extent, extent)
    -- 计数徽标不再叠进上一个头像，留出 4dp 呼吸位，避免“+1”被压住。
    params.leftMargin = dp(space(4))
    row.addView(more, params)
  end
  return row
end

-- 分页器：page 从 1 开始，total 为总页数。
function M.pagination(spec)
  spec = spec or {}
  local palette = colors()
  local current = math.floor(numberValue(spec.page, 1))
  local total = math.max(1, math.floor(numberValue(spec.total, 1)))
  current = math.max(1, math.min(total, current))
  local row = LinearLayout(activity)
  row.setOrientation(LinearLayout.HORIZONTAL)
  row.setGravity(Gravity.CENTER_HORIZONTAL + Gravity.CENTER_VERTICAL)

  local function item(label, target, active, enabled)
    local view = textView(label, TY.footnote.size, active and palette.onAccent or palette.label, active)
    view.setGravity(Gravity.CENTER)
    view.setMinWidth(dp(space(32)))
    view.setMinHeight(dp(space(32)))
    view.setPadding(dp(space(6)), 0, dp(space(6)), 0)
    view.setBackground(roundRect(active and palette.accent or palette.fill, R.segmentItem))
    if enabled ~= false and target then
      view.setOnClickListener(View.OnClickListener{
        onClick = function()
          if target ~= current and spec.onChange then
            spec.onChange(target)
          end
        end
      })
    else
      view.setAlpha(alphaValue(OP.disabled))
    end
    return view
  end

  local function arrowItem(name, target, enabled)
    local view = icons.chip(name, {
      size = 30,
      iconSize = 16,
      background = palette.fill,
      color = enabled and palette.label or palette.tertiary,
      radius = R.segmentItem,
    })
    if enabled ~= false and target then
      view.setOnClickListener(View.OnClickListener{
        onClick = function()
          if target ~= current and spec.onChange then
            spec.onChange(target)
          end
        end,
      })
    else
      view.setAlpha(alphaValue(OP.disabled))
    end
    return view
  end

  row.addView(arrowItem("chevron-left", current - 1, current > 1), LinearLayout.LayoutParams(dp(36), dp(space(32))))
  local start = math.max(1, current - 2)
  local finish = math.min(total, start + 4)
  start = math.max(1, finish - 4)
  for index = start, finish do
    local view = item(tostring(index), index, index == current, true)
    local params = LinearLayout.LayoutParams(-2, dp(space(32)))
    params.leftMargin = dp(space(4))
    row.addView(view, params)
  end
  local nextParams = LinearLayout.LayoutParams(dp(36), dp(space(32)))
  nextParams.leftMargin = dp(space(4))
  row.addView(arrowItem("chevron-right", current + 1, current < total), nextParams)
  return row
end

-- ===== 动画 =====
function M.animate(view, spec)
  spec = spec or {}
  if type(view) == "table" and view.view and type(view.view) ~= "function" then
    view = view.view
  end
  if not view then
    return nil
  end

  local preset = spec.preset or "up"
  local duration = timeValue(spec.duration or MO.slow, 260)
  local motionOffset = dp(space("motionY"))
  view.setAlpha(0)
  local enterScale = numberValue(MO.enterScale, 0.92)
  if preset == "scale" then
    view.setScaleX(enterScale)
    view.setScaleY(enterScale)
  elseif preset == "down" then
    view.setTranslationY(-motionOffset)
  elseif preset ~= "fade" then
    view.setTranslationY(motionOffset)
  end

  local animator = ValueAnimator.ofFloat(float{0, 1})
  animator.setDuration(duration)
  if spec.delay and spec.delay > 0 then
    animator.setStartDelay(timeValue(spec.delay, 0))
  end
  pcall(function()
    animator.setInterpolator(DecelerateInterpolator())
  end)
  animator.addUpdateListener(ValueAnimator.AnimatorUpdateListener{
    onAnimationUpdate = function(animation)
      local progress = animation.getAnimatedValue()
      view.setAlpha(progress)
      if preset == "scale" then
        view.setScaleX(enterScale + (1 - enterScale) * progress)
        view.setScaleY(enterScale + (1 - enterScale) * progress)
      elseif preset == "down" then
        view.setTranslationY(-motionOffset * (1 - progress))
      elseif preset ~= "fade" then
        view.setTranslationY(motionOffset * (1 - progress))
      end
    end,
  })
  animator.start()
  return animator
end

function M.stagger(views, spec)
  spec = spec or {}
  views = views or {}
  for index = 1, #views do
    local delay = timeValue(spec.delay, 0) + (index - 1) * timeValue(spec.step or MO.stagger, 55)
    M.animate(views[index], {
      preset = spec.preset or "up",
      duration = spec.duration or MO.staggerItem,
      delay = delay,
    })
  end
end

function M.press(view, spec)
  spec = spec or {}
  if type(view) == "table" and view.view and type(view.view) ~= "function" then
    view = view.view
  end
  view.setOnTouchListener(View.OnTouchListener{
    onTouch = function(target, event)
      local action = event.getAction()
      if action == 0 then
        local pressScale = numberValue(spec.scale or MO.pressScale, 0.97)
        target.animate().scaleX(pressScale).scaleY(pressScale).setDuration(timeValue(MO.fast, 90)).start()
      elseif action == 1 or action == 3 then
        target.animate().scaleX(1).scaleY(1).setDuration(timeValue(MO.normal, 120)).start()
      end
      return false
    end,
  })
  return view
end

M.dp = dp
M.number = numberValue
M.metric = dimension

return M
