require "import"
import "android.app.*"
import "android.os.*"
import "android.widget.*"
import "android.view.*"
import "android.graphics.Typeface"
import "android.graphics.drawable.GradientDrawable"
import "android.text.format.Formatter"
import "autotheme"

activity.setTheme(autotheme())
activity.setTitle("插件市场")

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
local Plugin = luajava.bindClass("com.mini.luaxplus.CompilerPlugin")
local Build = luajava.bindClass("android.os.Build")
local Toast = luajava.bindClass("android.widget.Toast")

local C = theme.colors
local BG = C.paper
local CARD = C.card
local INK = C.ink
local MUTED = C.muted
local LINE = C.line
local ACCENT = C.accent
local ACCENT_DEEP = C.accentDeep
local WASH = C.accentWash
local SUCCESS = C.success
local DANGER = C.danger

-- 插件包托管在 GitHub main 分支，下载后仍按整包 SHA-256 校验。
local COMPILER_URL = "https://raw.githubusercontent.com/Lisir2002/LuaXplus/main/dist/compiler-plugin-1.2.zip"
local COMPILER_SHA256 = "25b2a5d979ff1e054ef5c63ab635465eecb444a24913c37b100ce50c0615941a"
local COMPILER_SIZE_TEXT = "约 29 MB"

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

local function toast(text)
  Toast.makeText(activity, tostring(text), Toast.LENGTH_SHORT).show()
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

titleBox.addView(label("插件市场", 23, INK, true))
local sub = label("按需下载，让主程序保持轻量", 11.5, MUTED)
sub.setPadding(0, dp(2), 0, 0)
titleBox.addView(sub)

local scroll = ScrollView(activity)
scroll.setFillViewport(true)
local content = LinearLayout(activity)
content.setOrientation(LinearLayout.VERTICAL)
content.setPadding(dp(16), dp(4), dp(16), dp(28))
scroll.addView(content, LinearLayout.LayoutParams(-1, -2))
root.addView(scroll, LinearLayout.LayoutParams(-1, 0, 1))

local intro = label("ECJ 与 D8 不再随安装包内置。安装编译器插件后，Java 工程仍可正常编译、预览和打包。", 12, MUTED)
intro.setPadding(dp(8), dp(8), dp(8), dp(4))
content.addView(intro, LinearLayout.LayoutParams(-1, -2))

local card = LinearLayout(activity)
card.setOrientation(LinearLayout.VERTICAL)
card.setPadding(dp(16), dp(16), dp(16), dp(16))
card.setBackground(rounded(CARD, LINE, 16))
content.addView(card, LinearLayout.LayoutParams(-1, -2))

local cardTop = LinearLayout(activity)
cardTop.setOrientation(LinearLayout.HORIZONTAL)
cardTop.setGravity(Gravity.CENTER_VERTICAL)
card.addView(cardTop, LinearLayout.LayoutParams(-1, -2))

local badge = icons.chip("package", {
  size = 42,
  iconSize = 22,
  background = WASH,
  color = ACCENT_DEEP,
  radius = 12,
})
cardTop.addView(badge, LinearLayout.LayoutParams(dp(42), dp(42)))

local cardTitles = LinearLayout(activity)
cardTitles.setOrientation(LinearLayout.VERTICAL)
local titleParams = LinearLayout.LayoutParams(0, -2, 1)
titleParams.leftMargin = dp(12)
cardTop.addView(cardTitles, titleParams)

local pluginName = label("Java 编译器", 16, INK, true)
cardTitles.addView(pluginName)
local pluginDesc = label("ECJ 3.26.0 + D8 3.3.20 + android.jar", 11.5, MUTED)
pluginDesc.setPadding(0, dp(3), 0, 0)
cardTitles.addView(pluginDesc)

local statusBadge = label("未安装", 11, DANGER, true)
statusBadge.setGravity(Gravity.CENTER)
statusBadge.setPadding(dp(9), dp(4), dp(9), dp(4))
statusBadge.setBackground(rounded(0xFFFFF1EE, DANGER, 9))
card.addView(statusBadge, LinearLayout.LayoutParams(-2, -2))

local function statusLine(text)
  local view = label(text, 12, MUTED)
  view.setPadding(0, dp(7), 0, 0)
  card.addView(view, LinearLayout.LayoutParams(-1, -2))
  return view
end

local statusDetail = statusLine("安装后才能编译、预览和打包 Java 工程。")
local sizeText = statusLine("插件大小：" .. COMPILER_SIZE_TEXT)
local pathText = statusLine("安装位置：")

local action = label("下载并安装", 14, 0xFFFFFFFF, true)
action.setGravity(Gravity.CENTER)
action.setPadding(0, dp(12), 0, dp(12))
action.setBackground(rounded(ACCENT, nil, 12))
local actionParams = LinearLayout.LayoutParams(-1, -2)
actionParams.topMargin = dp(14)
card.addView(action, actionParams)

local refresh

local function setBusy(busy)
  action.setEnabled(not busy)
  action.setAlpha(busy and 0.55 or 1)
  if busy then
    action.setText("正在下载并安装…")
  else
    refresh()
  end
end

local function install()
  if Build.VERSION.SDK_INT < 26 then
    toast("手机内编译需要 Android 8.0 及以上系统")
    return
  end
  AlertDialog.Builder(activity)
    .setTitle("安装 Java 编译器")
    .setMessage("将从网络下载 " .. COMPILER_SIZE_TEXT .. " 的编译器插件，安装后即可编译、预览和打包 Java 工程。")
    .setNegativeButton("取消", nil)
    .setPositiveButton("开始下载", function()
      setBusy(true)
      local progress = ProgressDialog(activity)
      progress.setMessage("正在下载编译器插件…")
      progress.setCancelable(false)
      progress.show()
      local callback = luajava.createProxy("com.mini.luaxplus.CompilerPlugin$InstallCallback", {
        onResult = function(installed, error)
          pcall(function()
            if progress.isShowing() then
              progress.dismiss()
            end
          end)
          setBusy(false)
          if installed then
            toast("Java 编译器安装完成")
          else
            local reason = tostring(error or "")
            if reason == "" or reason == "nil" then
              reason = "下载或安装失败，请检查网络后重试"
            end
            toast("安装失败：" .. reason)
          end
        end
      })
      local ok, err = pcall(function()
        Plugin.downloadAndInstallAsync(activity, COMPILER_URL, COMPILER_SHA256, callback)
      end)
      if not ok then
        pcall(function()
          if progress.isShowing() then
            progress.dismiss()
          end
        end)
        setBusy(false)
        toast("安装启动失败：" .. tostring(err))
      end
    end)
    .show()
end

refresh = function()
  local installed = false
  local version = ""
  local bytes = 0
  local path = ""
  pcall(function()
    installed = Plugin.isInstalled(activity)
    version = tostring(Plugin.installedVersion(activity) or "")
    bytes = tonumber(Plugin.installedBytes(activity)) or 0
    path = Plugin.root(activity).getAbsolutePath()
  end)
  if installed then
    statusBadge.setText("已安装")
    statusBadge.setTextColor(SUCCESS)
    statusBadge.setBackground(rounded(0xFFEAF7F0, SUCCESS, 9))
    statusDetail.setText("编译器已就绪，Java 工程可以直接编译、预览和打包。")
    sizeText.setText("占用空间：" .. Formatter.formatFileSize(activity, bytes))
    action.setText("重新下载安装")
  else
    statusBadge.setText("未安装")
    statusBadge.setTextColor(DANGER)
    statusBadge.setBackground(rounded(0xFFFFF1EE, DANGER, 9))
    statusDetail.setText("安装后才能编译、预览和打包 Java 工程。")
    sizeText.setText("插件大小：" .. COMPILER_SIZE_TEXT)
    action.setText("下载并安装")
  end
  if version ~= "" and version ~= "nil" then
    pluginDesc.setText("ECJ 3.26.0 + D8 3.3.20 · v" .. version)
  end
  pathText.setText("安装位置：" .. tostring(path))
end

action.setOnClickListener(View.OnClickListener{
  onClick = function()
    install()
  end
})

local noteCard = LinearLayout(activity)
noteCard.setOrientation(LinearLayout.VERTICAL)
noteCard.setPadding(dp(16), dp(14), dp(16), dp(14))
noteCard.setBackground(rounded(CARD, LINE, 16))
local noteParams = LinearLayout.LayoutParams(-1, -2)
noteParams.topMargin = dp(12)
content.addView(noteCard, noteParams)

noteCard.addView(label("说明", 14, INK, true))
local lines = {
  "下载完成后会核对 SHA-256，并校验编译器 DEX 与 android.jar 的完整性。",
  "插件只加载 ECJ 与 D8 编译类，不会改动你的工程文件。",
  "开源许可：ECJ 采用 EPL-2.0，D8 采用 BSD-3-Clause；完整许可见插件 resources/licenses。",
  "插件安装在应用内部存储，不申请存储权限；清理应用数据或卸载应用后会提示重新安装。",
}
for _, text in ipairs(lines) do
  local line = label(text, 12, MUTED)
  line.setPadding(0, dp(7), 0, 0)
  noteCard.addView(line, LinearLayout.LayoutParams(-1, -2))
end

refresh()
theme.apply(activity, { background = BG, root = root, dark = false })
activity.setContentView(root)
