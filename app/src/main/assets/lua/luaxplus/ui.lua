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

local M = {}

-- ===== 主题 =====
-- 颜色取自 iOS 系统语义色，浅色与深色各一套。
local LIGHT = {
  bg = 0xFFF2F2F7,
  card = 0xFFFFFFFF,
  cardPressed = 0xFFE5E5EA,
  label = 0xFF000000,
  secondary = 0xFF8A8A8E,
  tertiary = 0xFFC7C7CC,
  separator = 0xFFC6C6C8,
  fill = 0xFFE9E9EB,
  blue = 0xFF007AFF,
  blueSoft = 0xFFE5F0FF,
  green = 0xFF34C759,
  red = 0xFFFF3B30,
  orange = 0xFFFF9500,
  purple = 0xFFAF52DE,
  pink = 0xFFFF2D55,
  yellow = 0xFFFFCC00,
  teal = 0xFF5AC8FA,
  gray = 0xFF8E8E93,
  white = 0xFFFFFFFF,
}

local DARK = {
  bg = 0xFF000000,
  card = 0xFF1C1C1E,
  cardPressed = 0xFF2C2C2E,
  label = 0xFFFFFFFF,
  secondary = 0xFF8D8D93,
  tertiary = 0xFF48484A,
  separator = 0xFF38383A,
  fill = 0xFF2C2C2E,
  blue = 0xFF0A84FF,
  blueSoft = 0xFF0A2540,
  green = 0xFF30D158,
  red = 0xFFFF453A,
  orange = 0xFFFF9F0A,
  purple = 0xFFBF5AF2,
  pink = 0xFFFF375F,
  yellow = 0xFFFFD60A,
  teal = 0xFF64D2FF,
  gray = 0xFF8D8D93,
  white = 0xFFFFFFFF,
}

M.appearance = "auto"

local function density()
  local current = activity
  if not current then
    return 2
  end
  return current.getResources().getDisplayMetrics().density
end

function M.dp(value)
  return math.floor(value * density() + 0.5)
end

local dp = M.dp

local function hairline()
  local value = dp(0.5)
  if value < 1 then
    return 1
  end
  return value
end

function M.isDark()
  if M.appearance == "dark" then
    return true
  elseif M.appearance == "light" then
    return false
  end
  local current = activity
  if not current then
    return false
  end
  local mode = current.getResources().getConfiguration().uiMode
  return math.floor(mode / 32) % 2 == 1
end

function M.palette()
  if M.isDark() then
    return DARK
  end
  return LIGHT
end

function M.setAppearance(mode)
  M.appearance = mode or "auto"
  return M.palette()
end

-- 允许调用方覆盖强调色，其余语义色保持系统风格
function M.setAccent(color)
  LIGHT.blue = color
  DARK.blue = color
end

local function colors()
  return M.palette()
end

-- ===== 基础绘制 =====
local function shape(fill, stroke, radius)
  local drawable = GradientDrawable()
  drawable.setShape(GradientDrawable.RECTANGLE)
  drawable.setColor(fill)
  drawable.setCornerRadius(dp(radius))
  if stroke then
    drawable.setStroke(hairline(), stroke)
  end
  return drawable
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
  view.setTextSize(size)
  view.setTextColor(color)
  if bold then
    view.setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL))
  else
    view.setTypeface(Typeface.create("sans-serif", Typeface.NORMAL))
  end
  return view
end

local function applySystemBars(dark)
  local current = activity
  if not current then
    return
  end
  pcall(function()
    local window = current.getWindow()
    window.setStatusBarColor(colors().bg)
    window.setNavigationBarColor(colors().bg)
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
  end)
end

-- ===== 页面骨架 =====
function M.page(options)
  options = options or {}
  local dark = M.isDark()
  local palette = M.palette()
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
  applySystemBars(dark)

  local root = LinearLayout(current)
  root.setOrientation(LinearLayout.VERTICAL)
  root.setBackgroundColor(options.background or palette.bg)
  root.setFitsSystemWindows(true)

  local nav = FrameLayout(current)
  nav.setBackgroundColor(options.navBackground or palette.card)
  root.addView(nav, LinearLayout.LayoutParams(-1, dp(44)))

  local navTitle = textView(options.title or "", 17, palette.label, true)
  navTitle.setGravity(Gravity.CENTER)
  local titleParams = FrameLayout.LayoutParams(-2, -2)
  titleParams.gravity = Gravity.CENTER
  nav.addView(navTitle, titleParams)

  if options.back then
    local back = textView("‹", 27, palette.blue, false)
    back.setGravity(Gravity.CENTER)
    back.setBackground(ripple(0x00000000, 22, 0x14000000))
    local backParams = FrameLayout.LayoutParams(dp(44), -1)
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
    local right = textView(rightSpec.title or "完成", 17, palette.blue, true)
    right.setGravity(Gravity.CENTER)
    right.setPadding(dp(12), 0, dp(12), 0)
    right.setBackground(ripple(0x00000000, 22, 0x14000000))
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
    local large = textView(options.title, 34, palette.label, true)
    large.setPadding(dp(16), dp(8), dp(16), dp(2))
    large.setIncludeFontPadding(false)
    root.addView(large, LinearLayout.LayoutParams(-1, -2))
    if options.subtitle then
      local subtitle = textView(options.subtitle, 13, palette.secondary, false)
      subtitle.setPadding(dp(16), 0, dp(16), dp(10))
      root.addView(subtitle, LinearLayout.LayoutParams(-1, -2))
    end
  elseif options.subtitle then
    local subtitle = textView(options.subtitle, 13, palette.secondary, false)
    subtitle.setPadding(dp(16), 0, dp(16), dp(8))
    root.addView(subtitle, LinearLayout.LayoutParams(-1, -2))
  end

  local scroll = ScrollView(current)
  scroll.setFillViewport(true)
  scroll.setVerticalScrollBarEnabled(false)
  local content = LinearLayout(current)
  content.setOrientation(LinearLayout.VERTICAL)
  content.setPadding(dp(16), dp(8), dp(16), dp(32))
  scroll.addView(content, LinearLayout.LayoutParams(-1, -2))
  root.addView(scroll, LinearLayout.LayoutParams(-1, 0, 1))

  local page = {
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
    params.topMargin = dp(topMargin or 0)
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
    current.setContentView(root)
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
  params.leftMargin = dp(leftInset or 16)
  return line, params
end

function M.row(spec)
  spec = spec or {}
  local palette = colors()
  local row = LinearLayout(activity)
  row.setOrientation(LinearLayout.HORIZONTAL)
  row.setGravity(Gravity.CENTER_VERTICAL)
  row.setMinimumHeight(dp(spec.height or 44))
  row.setPadding(dp(spec.icon and 12 or 16), dp(7), dp(12), dp(7))
  row.setBackground(ripple(0x00000000, 0, 0x14000000))

  if spec.icon then
    if type(spec.icon) == "string" then
      local badge = textView(spec.icon, 15, palette.white, true)
      badge.setGravity(Gravity.CENTER)
      badge.setBackground(roundRect(spec.iconBg or palette.blue, 7))
      local params = LinearLayout.LayoutParams(dp(29), dp(29))
      params.rightMargin = dp(11)
      row.addView(badge, params)
    else
      local params = LinearLayout.LayoutParams(dp(29), dp(29))
      params.rightMargin = dp(11)
      row.addView(spec.icon, params)
    end
  end

  local textBox = LinearLayout(activity)
  textBox.setOrientation(LinearLayout.VERTICAL)
  row.addView(textBox, LinearLayout.LayoutParams(0, -2, 1))

  local titleColor = spec.destructive and palette.red or palette.label
  local title = textView(spec.title or "", spec.titleSize or 17, titleColor, false)
  title.setSingleLine(true)
  title.setEllipsize(TextUtils.TruncateAt.END)
  textBox.addView(title)

  if spec.subtitle then
    local subtitle = textView(spec.subtitle, 13, palette.secondary, false)
    subtitle.setSingleLine(true)
    subtitle.setEllipsize(TextUtils.TruncateAt.END)
    subtitle.setPadding(0, dp(2), 0, 0)
    textBox.addView(subtitle)
  end

  if spec.value then
    local value = textView(spec.value, 15, palette.secondary, false)
    value.setSingleLine(true)
    value.setPadding(dp(8), 0, dp(2), 0)
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
        switchView.setTrackColors(palette.fill, palette.green)
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
    local check = textView("✓", 17, palette.blue, true)
    check.setPadding(dp(6), 0, dp(2), 0)
    row.addView(check)
  elseif spec.chevron ~= false and (spec.onClick or spec.chevron) then
    local chevron = textView("›", 20, palette.tertiary, false)
    chevron.setPadding(dp(6), 0, 0, 0)
    row.addView(chevron)
  end

  if spec.disabled then
    row.setAlpha(0.42)
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
    local caption = textView(string.upper(tostring(header)), 13, palette.secondary, false)
    caption.setLetterSpacing(0.04)
    caption.setPadding(dp(4), dp(6), dp(4), dp(6))
    box.addView(caption)
  end

  local card = LinearLayout(activity)
  card.setOrientation(LinearLayout.VERTICAL)
  card.setBackground(roundRect(palette.card, 12))
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
    local note = textView(tostring(footer), 13, palette.secondary, false)
    note.setPadding(dp(4), dp(7), dp(4), dp(4))
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
    fill = palette.blue
    textColor = palette.white
    rippleColor = 0x33FFFFFF
  elseif style == "tinted" then
    fill = palette.blueSoft
    textColor = palette.blue
    rippleColor = 0x22007AFF
  elseif style == "gray" then
    fill = palette.fill
    textColor = palette.label
    rippleColor = 0x22000000
  elseif style == "plain" then
    fill = 0x00000000
    textColor = palette.blue
    rippleColor = 0x14007AFF
  elseif style == "destructive" then
    fill = palette.red
    textColor = palette.white
    rippleColor = 0x33FFFFFF
  else
    fill = palette.blue
    textColor = palette.white
    rippleColor = 0x33FFFFFF
  end

  local button = textView(spec.text or "按钮", spec.textSize or 17, textColor, true)
  button.setGravity(Gravity.CENTER)
  button.setPadding(dp(14), dp(12), dp(14), dp(12))
  button.setMinimumHeight(dp(46))
  button.setBackground(ripple(fill, spec.radius or 12, rippleColor))
  if spec.enabled == false then
    button.setAlpha(0.45)
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
  input.setTextSize(spec.textSize or 17)
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
  row.setMinimumHeight(dp(44))
  row.setPadding(dp(16), dp(7), dp(16), dp(7))

  local label = textView(spec.label or "字段", 17, palette.label, false)
  label.setSingleLine(true)
  row.addView(label)

  local input = EditText(activity)
  configureInput(input, spec)
  input.setGravity(Gravity.RIGHT)
  local params = LinearLayout.LayoutParams(0, -2, 1)
  params.leftMargin = dp(12)
  row.addView(input, params)

  return { view = row, input = input }
end

function M.field(spec)
  spec = spec or {}
  local palette = colors()
  local box = LinearLayout(activity)
  box.setOrientation(LinearLayout.VERTICAL)
  if spec.label then
    local label = textView(spec.label, 13, palette.secondary, false)
    label.setPadding(dp(4), dp(6), dp(4), dp(6))
    box.addView(label)
  end
  local holder = LinearLayout(activity)
  holder.setOrientation(LinearLayout.VERTICAL)
  holder.setBackground(roundRect(palette.card, 12))
  holder.setPadding(dp(16), dp(10), dp(16), dp(10))
  local input = EditText(activity)
  configureInput(input, spec)
  holder.addView(input, LinearLayout.LayoutParams(-1, -2))
  box.addView(holder, LinearLayout.LayoutParams(-1, -2))
  if spec.footer then
    local note = textView(spec.footer, 13, palette.secondary, false)
    note.setPadding(dp(4), dp(6), dp(4), 0)
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
  bar.setBackground(roundRect(palette.fill, 10))
  bar.setPadding(dp(10), 0, dp(10), 0)

  local glyph = textView("⌕", 15, palette.secondary, false)
  bar.addView(glyph)

  local input = EditText(activity)
  configureInput(input, {
    hint = spec.hint or "搜索",
    value = spec.value,
    onChange = spec.onChange,
  })
  input.setTextSize(15)
  local params = LinearLayout.LayoutParams(0, dp(36), 1)
  params.leftMargin = dp(6)
  bar.addView(input, params)

  return bar
end

-- ===== 分段选择 =====
function M.segmented(spec)
  spec = spec or {}
  local palette = colors()
  local track = LinearLayout(activity)
  track.setOrientation(LinearLayout.HORIZONTAL)
  track.setBackground(roundRect(palette.fill, 9))
  track.setPadding(dp(2), dp(2), dp(2), dp(2))

  local labels = {}
  local items = spec.items or {}
  local selected = spec.selected or 1

  local function apply()
    for index = 1, #labels do
      local item = labels[index]
      if index == selected then
        item.setBackground(roundRect(palette.card, 7))
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
    local label = textView(value, 13, palette.label, false)
    label.setGravity(Gravity.CENTER)
    label.setPadding(dp(6), dp(6), dp(6), dp(6))
    track.addView(label, LinearLayout.LayoutParams(0, dp(28), 1))
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
  card.setBackground(roundRect(palette.card, 12))
  card.setPadding(dp(16), dp(16), dp(16), dp(16))

  if spec.title then
    local title = textView(spec.title, spec.titleSize or 17, palette.label, true)
    card.addView(title)
  end
  if spec.subtitle then
    local subtitle = textView(spec.subtitle, 14, palette.secondary, false)
    subtitle.setPadding(0, dp(4), 0, 0)
    card.addView(subtitle)
  end
  if content then
    local params = LinearLayout.LayoutParams(-1, -2)
    params.topMargin = dp(10)
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
  box.setPadding(dp(24), dp(44), dp(24), dp(44))

  local glyph
  if type(spec.icon) == "string" or spec.icon == nil then
    glyph = textView(spec.icon or "○", 44, palette.tertiary, false)
    glyph.setGravity(Gravity.CENTER)
  else
    glyph = spec.icon
  end
  box.addView(glyph)

  local title = textView(spec.title or "暂无内容", 17, palette.label, true)
  title.setGravity(Gravity.CENTER)
  title.setPadding(0, dp(12), 0, 0)
  box.addView(title)

  if spec.message then
    local message = textView(spec.message, 14, palette.secondary, false)
    message.setGravity(Gravity.CENTER)
    message.setPadding(0, dp(6), 0, 0)
    box.addView(message)
  end

  if spec.action then
    local action = M.button{
      text = spec.action.title or "去看看",
      style = "tinted",
      onClick = spec.action.onClick,
    }
    local params = LinearLayout.LayoutParams(-2, dp(46))
    params.topMargin = dp(16)
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
  box.setPadding(dp(24), dp(36), dp(24), dp(36))

  local progress = ProgressBar(activity)
  progress.setIndeterminate(true)
  pcall(function()
    progress.getIndeterminateDrawable().setColorFilter(palette.blue, PorterDuff.Mode.SRC_IN)
  end)
  box.addView(progress, LinearLayout.LayoutParams(dp(28), dp(28)))

  local label = textView(spec.text or "加载中…", 14, palette.secondary, false)
  label.setGravity(Gravity.CENTER)
  label.setPadding(0, dp(10), 0, 0)
  box.addView(label)
  return box
end

function M.avatar(name, color, size)
  local palette = colors()
  local initial = "?"
  if name and #tostring(name) > 0 then
    initial = string.sub(tostring(name), 1, 1)
  end
  local avatar = textView(string.upper(initial), math.floor((size or 40) / 2.4), palette.white, true)
  avatar.setGravity(Gravity.CENTER)
  avatar.setBackground(roundRect(color or palette.blue, (size or 40) / 2))
  avatar.setLayoutParams(LinearLayout.LayoutParams(dp(size or 40), dp(size or 40)))
  return avatar
end

function M.badge(text, color)
  local palette = colors()
  local badge = textView(text or "", 11, color or palette.red, true)
  badge.setGravity(Gravity.CENTER)
  badge.setPadding(dp(6), dp(2), dp(6), dp(2))
  badge.setBackground(roundRect(palette.fill, 8))
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
  view.setMinimumHeight(dp(height or 12))
  return view
end

function M.tabBar(spec)
  spec = spec or {}
  local palette = colors()
  local bar = LinearLayout(activity)
  bar.setOrientation(LinearLayout.HORIZONTAL)
  bar.setBackgroundColor(palette.card)
  bar.setPadding(0, dp(4), 0, dp(6))

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
      tab.icon.setTextColor(active and palette.blue or palette.gray)
      tab.label.setTextColor(active and palette.blue or palette.gray)
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
    tab.setPadding(0, dp(4), 0, dp(2))

    local icon = textView(item.icon or "•", 19, palette.gray, false)
    icon.setGravity(Gravity.CENTER)
    tab.addView(icon)

    local label = textView(item.title or "", 10, palette.gray, false)
    label.setGravity(Gravity.CENTER)
    tab.addView(label)

    bar.addView(tab, LinearLayout.LayoutParams(0, dp(45), 1))
    tab.setOnClickListener(View.OnClickListener{
      onClick = function()
        selected = index
        apply()
        if spec.onChange then
          spec.onChange(index, item)
        end
      end
    })
    tabs[index] = { icon = icon, label = label, root = tab }
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
  card.setBackground(roundRect(palette.card, 14))
  card.setClipToOutline(true)

  local title = textView(spec.title or "提示", 17, palette.label, true)
  title.setGravity(Gravity.CENTER)
  title.setPadding(dp(19), dp(19), dp(19), 0)
  card.addView(title, LinearLayout.LayoutParams(-1, -2))

  if spec.message then
    local message = textView(spec.message, 13, palette.secondary, false)
    message.setGravity(Gravity.CENTER)
    message.setPadding(dp(19), dp(7), dp(19), dp(19))
    card.addView(message, LinearLayout.LayoutParams(-1, -2))
  else
    local gap = View(current)
    gap.setLayoutParams(LinearLayout.LayoutParams(1, dp(10)))
    card.addView(gap)
  end

  local actions = spec.actions or {}
  if #actions == 0 then
    actions = { { title = "好" } }
  end

  local function makeAction(action)
    local color = palette.blue
    if action.style == "destructive" then
      color = palette.red
    end
    local button = textView(action.title or "好", 17, color, action.style == "cancel")
    button.setGravity(Gravity.CENTER)
    button.setBackground(ripple(0x00000000, 0, 0x14000000))
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
      row.addView(makeAction(actions[index]), LinearLayout.LayoutParams(0, dp(44), 1))
    end
    card.addView(row, LinearLayout.LayoutParams(-1, -2))
  else
    for index = 1, #actions do
      local line = View(current)
      line.setBackgroundColor(palette.separator)
      card.addView(line, LinearLayout.LayoutParams(-1, hairline()))
      card.addView(makeAction(actions[index]), LinearLayout.LayoutParams(-1, dp(44)))
    end
  end

  dialog.setContentView(card)
  local window = dialog.getWindow()
  if window then
    window.setBackgroundDrawable(ColorDrawable(0x00000000))
    window.addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
    window.setDimAmount(0.35)
    window.setGravity(Gravity.CENTER)
    window.setLayout(dp(270), -2)
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
  root.setPadding(dp(8), dp(8), dp(8), dp(24))

  local group = LinearLayout(current)
  group.setOrientation(LinearLayout.VERTICAL)
  group.setBackground(roundRect(palette.card, 14))
  group.setClipToOutline(true)

  if spec.title or spec.message then
    local head = LinearLayout(current)
    head.setOrientation(LinearLayout.VERTICAL)
    head.setPadding(dp(16), dp(14), dp(16), dp(14))
    if spec.title then
      local title = textView(spec.title, 13, palette.secondary, true)
      title.setGravity(Gravity.CENTER)
      head.addView(title)
    end
    if spec.message then
      local message = textView(spec.message, 13, palette.secondary, false)
      message.setGravity(Gravity.CENTER)
      message.setPadding(0, dp(4), 0, 0)
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
    local color = action.style == "destructive" and palette.red or palette.blue
    local item = textView(action.title or "", 20, color, false)
    item.setGravity(Gravity.CENTER)
    item.setBackground(ripple(0x00000000, 0, 0x14000000))
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
    group.addView(item, LinearLayout.LayoutParams(-1, dp(57)))
  end
  root.addView(group, LinearLayout.LayoutParams(-1, -2))

  local cancel = textView(spec.cancelText or "取消", 20, palette.blue, true)
  cancel.setGravity(Gravity.CENTER)
  cancel.setBackground(ripple(palette.card, 14, 0x14000000))
  local cancelParams = LinearLayout.LayoutParams(-1, dp(57))
  cancelParams.topMargin = dp(8)
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
    window.setDimAmount(0.35)
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
  local fill = selected and (spec.color or palette.blue) or palette.fill
  local textColor = selected and palette.white or palette.label

  local chip = textView(spec.text or "", spec.textSize or 14, textColor, true)
  chip.setGravity(Gravity.CENTER)
  chip.setPadding(dp(12), dp(7), dp(12), dp(7))
  chip.setMinHeight(dp(32))
  chip.setBackground(roundRect(fill, 16))
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
      chip.setTextColor(active and palette.white or palette.label)
      chip.setBackground(roundRect(active and palette.blue or palette.fill, 16))
    end
  end

  for index = 1, #items do
    local item = items[index]
    if type(item) ~= "table" then
      item = { text = tostring(item) }
    end
    local chip = M.chip({ text = item.text or item.title or "", textSize = 13 })
    local params = LinearLayout.LayoutParams(-2, -2)
    if index > 1 then
      params.leftMargin = dp(8)
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
  row.setMinimumHeight(dp(46))
  row.setPadding(dp(16), dp(7), dp(14), dp(7))
  row.setBackground(ripple(0x00000000, 0, 0x14000000))

  local textBox = LinearLayout(activity)
  textBox.setOrientation(LinearLayout.VERTICAL)
  row.addView(textBox, LinearLayout.LayoutParams(0, -2, 1))

  local title = textView(spec.title or "", 16, palette.label, false)
  textBox.addView(title)
  if spec.subtitle then
    local subtitle = textView(spec.subtitle, 13, palette.secondary, false)
    subtitle.setPadding(0, dp(2), 0, 0)
    textBox.addView(subtitle)
  end

  local mark = textView("", 14, palette.white, true)
  mark.setGravity(Gravity.CENTER)
  row.addView(mark, LinearLayout.LayoutParams(dp(24), dp(24)))

  local function apply()
    mark.setText(checked and "✓" or "")
    mark.setTextColor(checked and palette.white or palette.tertiary)
    mark.setBackground(checked and roundRect(palette.blue, 12) or shape(0x00000000, palette.tertiary, 12))
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
  local valueView = textView("", 13, palette.secondary, false)
  if spec.label then
    local label = textView(spec.label, 14, palette.label, false)
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
    seek.setProgressTintList(ColorStateList.valueOf(palette.blue))
    seek.setThumbTintList(ColorStateList.valueOf(palette.blue))
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
    local label = textView(spec.label, 13, palette.secondary, false)
    label.setPadding(dp(4), dp(4), dp(4), dp(4))
    box.addView(label)
  end

  local row = LinearLayout(activity)
  row.setOrientation(LinearLayout.HORIZONTAL)
  row.setGravity(Gravity.CENTER_VERTICAL)

  local function control(text)
    local view = textView(text, 22, palette.blue, false)
    view.setGravity(Gravity.CENTER)
    view.setBackground(roundRect(palette.fill, 10))
    row.addView(view, LinearLayout.LayoutParams(dp(38), dp(38)))
    return view
  end

  local minus = control("−")
  local valueView = textView("", 17, palette.label, true)
  valueView.setGravity(Gravity.CENTER)
  row.addView(valueView, LinearLayout.LayoutParams(0, dp(38), 1))
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
    bar.setProgressTintList(ColorStateList.valueOf(spec.color or palette.blue))
  end)

  local box = LinearLayout(activity)
  box.setOrientation(LinearLayout.VERTICAL)
  if spec.label then
    local label = textView(spec.label, 13, palette.secondary, false)
    label.setPadding(dp(4), dp(4), dp(4), dp(2))
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
  local animator = ValueAnimator.ofFloat(float{0.28, 0.72})
  animator.setDuration(spec.duration or 900)
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
  box.setPadding(dp(16), dp(16), dp(16), dp(16))
  box.setBackground(roundRect(palette.card, 12))

  local lines = spec.lines or 3
  for index = 1, lines do
    local line = View(activity)
    line.setBackground(roundRect(palette.fill, 6))
    local width = index == lines and 0.55 or (index == 1 and 0.86 or 0.7)
    local params = LinearLayout.LayoutParams(-1, dp(index == 1 and 16 or 12))
    if index > 1 then
      params.topMargin = dp(10)
    end
    if width < 1 then
      local holder = LinearLayout(activity)
      holder.setOrientation(LinearLayout.HORIZONTAL)
      holder.addView(line, LinearLayout.LayoutParams(0, dp(index == 1 and 16 or 12), width))
      local rest = View(activity)
      holder.addView(rest, LinearLayout.LayoutParams(0, 1, 1 - width))
      box.addView(holder, params)
    else
      box.addView(line, params)
    end
  end

  local animator = M.shimmer(box, { duration = spec.duration or 900 })
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
  card.setPadding(dp(14), dp(13), dp(14), dp(13))
  card.setBackground(roundRect(spec.background or palette.blueSoft, 12))

  local header = LinearLayout(activity)
  header.setOrientation(LinearLayout.HORIZONTAL)
  header.setGravity(Gravity.CENTER_VERTICAL)
  card.addView(header)

  local glyph = textView(spec.icon or "i", 14, palette.white, true)
  glyph.setGravity(Gravity.CENTER)
  glyph.setBackground(roundRect(spec.color or palette.blue, 9))
  header.addView(glyph, LinearLayout.LayoutParams(dp(28), dp(28)))

  local title = textView(spec.title or "提示", 15, palette.label, true)
  title.setPadding(dp(10), 0, 0, 0)
  header.addView(title, LinearLayout.LayoutParams(0, -2, 1))

  if spec.message then
    local message = textView(spec.message, 13, palette.secondary, false)
    message.setPadding(dp(38), dp(4), 0, 0)
    card.addView(message)
  end

  if spec.action then
    local action = M.button({
      text = spec.action.title or "查看",
      style = "plain",
      textSize = 13,
      onClick = spec.action.onClick,
    })
    local params = LinearLayout.LayoutParams(-2, dp(44))
    params.leftMargin = dp(38)
    params.topMargin = dp(4)
    card.addView(action, params)
  end
  return card
end

function M.stat(spec)
  spec = spec or {}
  local palette = colors()
  local card = LinearLayout(activity)
  card.setOrientation(LinearLayout.VERTICAL)
  card.setPadding(dp(14), dp(14), dp(14), dp(14))
  card.setBackground(roundRect(palette.card, 12))

  local value = textView(spec.value or "0", spec.valueSize or 28, spec.color or palette.label, true)
  value.setIncludeFontPadding(false)
  card.addView(value)

  local label = textView(spec.label or "", 13, palette.secondary, false)
  label.setPadding(0, dp(4), 0, 0)
  card.addView(label)

  if spec.note then
    local note = textView(spec.note, 11, spec.noteColor or palette.blue, true)
    note.setPadding(0, dp(6), 0, 0)
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
      params.leftMargin = dp(spec.gap or 8)
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
  local fab = textView(spec.text or "+", spec.textSize or 26, palette.white, true)
  fab.setGravity(Gravity.CENTER)
  fab.setBackground(roundRect(spec.color or palette.blue, 26))
  fab.setMinWidth(dp(52))
  fab.setMinHeight(dp(52))
  fab.setElevation(dp(6))
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
  box.setPadding(dp(16), dp(10), dp(16), dp(10))
  box.setBackground(roundRect(palette.card, 18))
  local text = textView(spec.text or "", 13, palette.label, false)
  box.addView(text)

  local toast = Toast.makeText(activity, "", spec.long and Toast.LENGTH_LONG or Toast.LENGTH_SHORT)
  toast.setView(box)
  toast.setGravity(Gravity.BOTTOM, 0, dp(spec.offset or 72))
  toast.show()
  return toast
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
  local duration = spec.duration or 260
  view.setAlpha(0)
  if preset == "scale" then
    view.setScaleX(0.92)
    view.setScaleY(0.92)
  elseif preset == "down" then
    view.setTranslationY(-dp(14))
  elseif preset ~= "fade" then
    view.setTranslationY(dp(14))
  end

  local animator = ValueAnimator.ofFloat(float{0, 1})
  animator.setDuration(duration)
  if spec.delay and spec.delay > 0 then
    animator.setStartDelay(spec.delay)
  end
  pcall(function()
    animator.setInterpolator(DecelerateInterpolator())
  end)
  animator.addUpdateListener(ValueAnimator.AnimatorUpdateListener{
    onAnimationUpdate = function(animation)
      local progress = animation.getAnimatedValue()
      view.setAlpha(progress)
      if preset == "scale" then
        view.setScaleX(0.92 + 0.08 * progress)
        view.setScaleY(0.92 + 0.08 * progress)
      elseif preset == "down" then
        view.setTranslationY(-dp(14) * (1 - progress))
      elseif preset ~= "fade" then
        view.setTranslationY(dp(14) * (1 - progress))
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
    local delay = (spec.delay or 0) + (index - 1) * (spec.step or 55)
    M.animate(views[index], {
      preset = spec.preset or "up",
      duration = spec.duration or 280,
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
        target.animate().scaleX(spec.scale or 0.97).scaleY(spec.scale or 0.97).setDuration(90).start()
      elseif action == 1 or action == 3 then
        target.animate().scaleX(1).scaleY(1).setDuration(120).start()
      end
      return false
    end,
  })
  return view
end


return M
