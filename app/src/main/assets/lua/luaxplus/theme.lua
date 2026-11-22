-- LuaX-UI 品牌主题：所有页面共用同一套纸感色板和系统栏处理。
-- 页面只读取这里的颜色，不再各自写死十六进制值；后续换主题只需要改这一处。

require "import"
import "android.os.*"
import "android.graphics.drawable.ColorDrawable"

local M = {}

M.colors = {
  paper = 0xFFF7F1E6,
  paperSoft = 0xFFF2ECE0,
  card = 0xFFFFFDF8,
  ink = 0xFF1C2B3A,
  muted = 0xFF5F6F7C,
  mutedSoft = 0xFF7D8B96,
  mutedLight = 0xFF9FB0BA,
  line = 0xFFE6DBC8,
  paperLine = 0xFFECEFF2,
  accent = 0xFF0F9E97,
  accentDeep = 0xFF0B6F6A,
  accentSoft = 0xFFDFF3F0,
  accentWash = 0xFFDFF3F0,
  accentLine = 0xFFBFE6E1,
  onAccent = 0xFFFFFFFF,
  warmInk = 0xFF7A6A56,
  warmWash = 0xFFF0E4D4,
  infoInk = 0xFF1F5F8B,
  infoWash = 0xFFE3F0FA,
  infoBg = 0xFFF3F6F9,
  infoLine = 0xFFD8E3EC,
  infoText = 0xFF16324A,
  blueInk = 0xFF4A6FA5,
  blueWash = 0xFFE2ECF8,
  brownInk = 0xFF8A5A2B,
  brownWash = 0xFFF7E6D2,
  danger = 0xFFD9534F,
  warning = 0xFFD98A2B,
  success = 0xFF2E9E6B,
  panel = 0xFF1B232C,
  panelSoft = 0xFF232D38,
  panelLine = 0xFF33404D,
  panelText = 0xFFE8EEF4,
  panelMuted = 0xFF90A0AE,
  panelDeep = 0xFF141B22,
  panelKey = 0xFF2B3744,
  panelTextSoft = 0xFFD6DDE5,
  editorDarkBg = 0xFF141A20,
  onAccentDeep = 0xFF07130F,
  successText = 0xFF6FBF9A,
  shadow = 0x14000000,
}

M.dark = {
  paper = 0xFF101416,
  paperSoft = 0xFF182025,
  card = 0xFF1B2326,
  ink = 0xFFF1EDE4,
  muted = 0xFFA5B3B7,
  mutedSoft = 0xFF8E9CA1,
  mutedLight = 0xFF6F7F85,
  line = 0xFF34403F,
  paperLine = 0xFF2A3438,
  accent = 0xFF35C8BE,
  accentDeep = 0xFF5BD9D0,
  accentSoft = 0xFF163B39,
  accentWash = 0xFF163B39,
  accentLine = 0xFF285B56,
  onAccent = 0xFFFFFFFF,
  warmInk = 0xFFD9C7B0,
  warmWash = 0xFF2B241C,
  infoInk = 0xFF9CC7E8,
  infoWash = 0xFF182B3A,
  infoBg = 0xFF152027,
  infoLine = 0xFF2B3C47,
  infoText = 0xFFD7E7F2,
  blueInk = 0xFF8FB5E0,
  blueWash = 0xFF1A2A3D,
  brownInk = 0xFFD4AA7A,
  brownWash = 0xFF2B2117,
  danger = 0xFFFF6B5E,
  warning = 0xFFF0B35A,
  success = 0xFF5BD39A,
  panel = 0xFF101416,
  panelSoft = 0xFF182025,
  panelLine = 0xFF2C393E,
  panelText = 0xFFF1EDE4,
  panelMuted = 0xFFA5B3B7,
  panelDeep = 0xFF0B1014,
  panelKey = 0xFF223039,
  panelTextSoft = 0xFFD6DDE5,
  editorDarkBg = 0xFF0D1216,
  onAccentDeep = 0xFF07130F,
  successText = 0xFF6FBF9A,
  shadow = 0x66000000,
}

function M.isDark()
  local current = activity
  if not current then
    return false
  end
  local mode = current.getResources().getConfiguration().uiMode
  return math.floor(mode / 32) % 2 == 1
end

function M.palette(dark)
  return dark and M.dark or M.colors
end

-- 把 ui 组件库切到纸感主题。已经注册过也不会重复注册。
function M.install(ui, mode)
  if not ui then
    return nil
  end
  if ui.defineTheme then
    pcall(function()
      ui.defineTheme("paper", {
        color = M.colors,
        dark = { color = M.dark },
      })
    end)
  end
  if ui.useTheme then
    ui.useTheme("paper", mode or "light")
  end
  return ui
end

-- 统一系统栏：去掉半透明遮罩，状态栏和页面顶部同色，导航栏和页面底部同色。
-- options.background / statusBar / navigationBar 都是颜色数值；dark=true 表示浅色图标。
function M.apply(target, options)
  target = target or activity
  if not target then
    return
  end
  options = options or {}
  local background = options.background or M.colors.paper
  local statusBar = options.statusBar or background
  local navigationBar = options.navigationBar or background
  local dark = options.dark
  if dark == nil then
    dark = M.isDark()
  end
  -- Android 6.0 以下没有“深色状态栏图标”开关，浅色栏会看不清图标，退回品牌深色。
  if not dark and Build.VERSION.SDK_INT < 23 then
    statusBar = M.colors.accentDeep
  end

  pcall(function()
    local window = target.getWindow()
    local params = luajava.bindClass("android.view.WindowManager$LayoutParams")
    window.addFlags(params.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
    window.clearFlags(params.FLAG_TRANSLUCENT_STATUS)
    window.clearFlags(params.FLAG_TRANSLUCENT_NAVIGATION)
  end)
  pcall(function()
    local window = target.getWindow()
    window.setStatusBarColor(statusBar)
    window.setNavigationBarColor(navigationBar)
    window.setBackgroundDrawable(ColorDrawable(background))
  end)

  pcall(function()
      local decor = target.getWindow().getDecorView()
      local flags = decor.getSystemUiVisibility()
      if dark then
        flags = flags & ~8192 & ~16
      else
        flags = flags | 8192
        if android.os.Build.VERSION.SDK_INT >= 26 then
          flags = flags | 16
        end
      end
      decor.setSystemUiVisibility(flags)
    end)

  if options.root then
    options.root.setBackgroundColor(background)
    if options.fit ~= false then
      options.root.setFitsSystemWindows(true)
    end
  end
end

return M
