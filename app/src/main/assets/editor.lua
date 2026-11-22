require "import"
import "android.app.*"
import "android.os.*"
import "android.widget.*"
import "android.view.*"
import "android.graphics.Typeface"
import "android.graphics.drawable.*"
import "android.text.*"
import "java.io.File"
import "com.androlua.LuaEditor"
import "com.mini.luaxplus.editor.EditorLanguage"
import "com.google.android.material.dialog.MaterialAlertDialogBuilder"
import "autotheme"

-- 独立编辑页：顶部操作栏、代码区、查找替换、符号条、状态栏

activity.setTheme(autotheme())

local theme = require "luaxplus.theme"
local icons = require "luaxplus.icons"
local lint = require "luaxplus.lint"
local EditorPalette = luajava.bindClass("com.mini.luaxplus.editor.EditorPalette")
local C = theme.colors
local PAPER = C.paper
local PANEL = C.panel
local PANEL_SOFT = C.panelSoft
local PANEL_LINE = C.panelLine
local TEXT_MAIN = C.panelText
local TEXT_MUTED = C.panelMuted
local ACCENT = C.accent
local INK = C.ink
local CARD = C.card
local LINE = C.line
local PANEL_DEEP = C.panelDeep
local PANEL_KEY = C.panelKey
local PANEL_TEXT_SOFT = C.panelTextSoft
local EDITOR_DARK_BG = C.editorDarkBg
local ON_ACCENT_DEEP = C.onAccentDeep
local SUCCESS_TEXT = C.successText

local args = {...}
local filePath = args[1]
if type(filePath) == "table" then
  filePath = filePath[1]
end
filePath = tostring(filePath or "")
if filePath == "" then
  Toast.makeText(activity, "没有指定文件", Toast.LENGTH_SHORT).show()
  activity.finish()
  return
end

local TextUtil = luajava.bindClass("com.mini.luaxplus.TextUtil")

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

local function readFile(path)
  local file = io.open(path, "r")
  if not file then
    return ""
  end
  local content = file:read("a")
  file:close()
  return content or ""
end

local function writeFile(path, content)
  local file = io.open(path, "w")
  if not file then
    return false
  end
  file:write(content)
  file:close()
  return true
end

local fileName = File(filePath).getName()
local fileExists = File(filePath).exists()
local savedText = readFile(filePath)
local darkMode = false

-- 语法高亮只按文件扩展名自动识别，不提供手动切换
local languageId = EditorLanguage.detect(filePath)
local languageName = EditorLanguage.displayName(languageId)
local languageText
local refreshStatus

activity.setTitle(fileName)

-- 页面自带操作栏，隐藏系统标题栏避免出现两层白条
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

if not fileExists then
  Toast.makeText(activity, "文件不存在，保存后会创建", Toast.LENGTH_SHORT).show()
end

local root = LinearLayout(activity)
root.setOrientation(LinearLayout.VERTICAL)
root.setBackgroundColor(PANEL)
root.setFitsSystemWindows(true)
theme.apply(activity, { background = PANEL, statusBar = PANEL, navigationBar = PANEL, root = root, dark = true })
activity.setContentView(root)

-- ===== 顶部操作栏 =====
local bar = LinearLayout(activity)
bar.setOrientation(LinearLayout.HORIZONTAL)
bar.setGravity(Gravity.CENTER_VERTICAL)
bar.setBackgroundColor(PANEL_SOFT)
bar.setPadding(dp(6), dp(4), dp(8), dp(4))

local function setButtonIcon(view, name, color)
  local id = icons.drawable(name)
  if not id then
    return
  end
  view.setCompoundDrawablesWithIntrinsicBounds(id, 0, 0, 0)
  view.setCompoundDrawablePadding(dp(4))
  pcall(function()
    local drawable = view.getCompoundDrawables()[0]
    if drawable then
      icons.tintDrawable(drawable, color or TEXT_MUTED)
    end
  end)
end

local function barButton(text, width, iconName)
  local view = TextView(activity)
  view.setText(text)
  view.setTextSize(13)
  view.setTextColor(TEXT_MAIN)
  view.setGravity(Gravity.CENTER)
  view.setPadding(dp(9), dp(7), dp(9), dp(7))
  view.setBackground(rounded(0x00000000, nil, 8))
  if iconName then
    setButtonIcon(view, iconName, TEXT_MUTED)
  end
  if width then
    bar.addView(view, LinearLayout.LayoutParams(dp(width), -2))
  else
    bar.addView(view, LinearLayout.LayoutParams(-2, -2))
  end
  return view
end

local function iconButton(name, width, size, color)
  local view = icons.view(name, { size = size or 18, color = color or TEXT_MUTED })
  view.setBackground(rounded(0x00000000, nil, 8))
  local params = LinearLayout.LayoutParams(dp(width or 30), dp(34))
  bar.addView(view, params)
  return view
end

local backBtn = iconButton("chevron-left", 30, 19, TEXT_MUTED)

local titleBox = LinearLayout(activity)
titleBox.setOrientation(LinearLayout.VERTICAL)
titleBox.setPadding(dp(2), 0, dp(4), 0)
bar.addView(titleBox, LinearLayout.LayoutParams(0, -2, 1))

local titleText = TextView(activity)
titleText.setText(fileName)
titleText.setTextSize(14)
titleText.setTypeface(Typeface.DEFAULT_BOLD)
titleText.setTextColor(TEXT_MAIN)
titleText.setSingleLine(true)
titleText.setEllipsize(TextUtils.TruncateAt.MIDDLE)
titleBox.addView(titleText, LinearLayout.LayoutParams(-1, -2))

local pathText = TextView(activity)
local shownPath = (filePath:gsub("^/storage/emulated/0/", ""))
pathText.setText(shownPath)
pathText.setTextSize(10)
pathText.setTextColor(TEXT_MUTED)
pathText.setSingleLine(true)
pathText.setEllipsize(TextUtils.TruncateAt.MIDDLE)
titleBox.addView(pathText, LinearLayout.LayoutParams(-1, -2))

local undoBtn = iconButton("undo", 28, 17, TEXT_MUTED)
local redoBtn = iconButton("redo", 28, 17, TEXT_MUTED)

undoBtn.setOnClickListener(View.OnClickListener{
  onClick = function()
    pcall(function()
      editor.undo()
    end)
    refreshStatus()
  end
})

redoBtn.setOnClickListener(View.OnClickListener{
  onClick = function()
    pcall(function()
      editor.redo()
    end)
    refreshStatus()
  end
})

local wrapBtn = barButton("换行", nil, "wrap")
wrapBtn.setTextSize(11)
wrapBtn.setTextColor(TEXT_MUTED)

local findBtn = barButton("搜索", nil, "search")
findBtn.setTextSize(12)
findBtn.setTextColor(TEXT_MUTED)

local saveBtn = barButton("保存", nil, "save")
saveBtn.setTextSize(12)
saveBtn.setTextColor(ON_ACCENT_DEEP)
saveBtn.setBackground(rounded(ACCENT, nil, 8))
setButtonIcon(saveBtn, "save", ON_ACCENT_DEEP)
local saveParams = LinearLayout.LayoutParams(-2, -2)
saveParams.leftMargin = dp(4)
bar.removeView(saveBtn)
bar.addView(saveBtn, saveParams)

local moreBtn = iconButton("more", 32, 18, TEXT_MUTED)

root.addView(bar, LinearLayout.LayoutParams(-1, -2))

-- ===== 代码区 =====
local editor = LuaEditor(activity)

-- 高亮色不能只依赖编辑器默认配色，否则标识符会和深色背景混在一起。
local function applyEditorColors(isDark)
  EditorPalette.apply(editor, isDark)
  editor.setBackgroundColor(isDark and EDITOR_DARK_BG or PAPER)
  pcall(function()
    editor.respan()
  end)
end

applyEditorColors(darkMode)
editor.setShowLineNumbers(true)
editor.setHighlightCurrentRow(true)
editor.setWordWrap(false)
editor.setAutoIndent(true)
editor.setAutoIndentWidth(4)
editor.setTabSpaces(4)
editor.setAutoComplete(true)
editor.setTextSize(17)
editor.setText(savedText)
editor.requestFocus()

local wrapEnabled = false
local function refreshWrapButton()
  if wrapEnabled then
    wrapBtn.setTextColor(ON_ACCENT_DEEP)
    wrapBtn.setBackground(rounded(ACCENT, nil, 8))
  else
    wrapBtn.setTextColor(TEXT_MUTED)
    wrapBtn.setBackground(rounded(0x00000000, PANEL_LINE, 8))
  end
end

wrapBtn.setOnClickListener(View.OnClickListener{
  onClick = function()
    wrapEnabled = not wrapEnabled
    editor.setWordWrap(wrapEnabled)
    refreshWrapButton()
    toast(wrapEnabled and "已开启自动换行" or "已关闭自动换行")
  end
})

refreshWrapButton()

-- ===== 查找替换 =====
local findPanel = LinearLayout(activity)
findPanel.setOrientation(LinearLayout.VERTICAL)
findPanel.setBackgroundColor(PANEL_SOFT)
findPanel.setPadding(dp(10), dp(6), dp(10), dp(8))
findPanel.setVisibility(View.GONE)

local function panelInput(hint, panel)
  local input = EditText(activity)
  input.setHint(hint)
  input.setTextSize(12)
  input.setTextColor(TEXT_MAIN)
  input.setHintTextColor(TEXT_MUTED)
  input.setSingleLine(true)
  input.setBackground(rounded(PANEL_DEEP, PANEL_LINE, 8))
  input.setPadding(dp(8), dp(5), dp(8), dp(5))
  panel.addView(input, LinearLayout.LayoutParams(0, -2, 1))
  return input
end

local rowFind = LinearLayout(activity)
rowFind.setOrientation(LinearLayout.HORIZONTAL)
rowFind.setGravity(Gravity.CENTER_VERTICAL)
findPanel.addView(rowFind, LinearLayout.LayoutParams(-1, -2))

local queryInput = panelInput("查找内容", rowFind)

local countText = TextView(activity)
countText.setTextColor(TEXT_MUTED)
countText.setTextSize(11)
countText.setPadding(dp(8), 0, dp(8), 0)
rowFind.addView(countText, LinearLayout.LayoutParams(-2, -2))

local function smallButton(text, parent)
  local view = TextView(activity)
  view.setText(text)
  view.setTextSize(11)
  view.setTextColor(TEXT_MAIN)
  view.setGravity(Gravity.CENTER)
  view.setPadding(dp(8), dp(5), dp(8), dp(5))
  view.setBackground(rounded(PANEL_KEY, PANEL_LINE, 7))
  local params = LinearLayout.LayoutParams(-2, -2)
  params.leftMargin = dp(4)
  parent.addView(view, params)
  return view
end

local prevBtn = smallButton("上一个", rowFind)
local nextBtn = smallButton("下一个", rowFind)
local closeBtn = smallButton("关闭", rowFind)

local rowReplace = LinearLayout(activity)
rowReplace.setOrientation(LinearLayout.HORIZONTAL)
rowReplace.setGravity(Gravity.CENTER_VERTICAL)
local replaceParams = LinearLayout.LayoutParams(-1, -2)
replaceParams.topMargin = dp(6)
findPanel.addView(rowReplace, replaceParams)

local replaceInput = panelInput("替换为", rowReplace)
local replaceBtn = smallButton("替换", rowReplace)
local replaceAllBtn = smallButton("全部替换", rowReplace)

root.addView(findPanel, 1, LinearLayout.LayoutParams(-1, -2))
root.addView(editor, LinearLayout.LayoutParams(-1, 1, 1))

-- ===== 符号与快捷操作条 =====
local stripScroll = HorizontalScrollView(activity)
stripScroll.setHorizontalScrollBarEnabled(false)
stripScroll.setBackgroundColor(PANEL_SOFT)

local strip = LinearLayout(activity)
strip.setOrientation(LinearLayout.HORIZONTAL)
strip.setGravity(Gravity.CENTER_VERTICAL)
strip.setPadding(dp(6), dp(3), dp(6), dp(3))
stripScroll.addView(strip, LinearLayout.LayoutParams(-2, -2))

local function stripChip(text, accent)
  local view = TextView(activity)
  view.setText(text)
  view.setTextSize(13)
  view.setTextColor(accent and ACCENT or TEXT_MUTED)
  view.setGravity(Gravity.CENTER)
  view.setPadding(dp(9), dp(4), dp(9), dp(4))
  view.setBackground(rounded(0x00000000, nil, 6))
  local params = LinearLayout.LayoutParams(-2, -2)
  params.rightMargin = dp(2)
  strip.addView(view, params)
  return view
end

local function insertSymbol(text)
  pcall(function()
    editor.paste(text)
  end)
end

local SYMBOLS = { "Tab", "{", "}", "(", ")", "\"", "'", "[", "]", "=", "==", "~=", "..", ",", ";", ":", "+", "-", "*", "/", "#", "<", ">", "|" }
for _, symbol in ipairs(SYMBOLS) do
  local chip = stripChip(symbol)
  chip.setOnClickListener(View.OnClickListener{
    onClick = function()
      if symbol == "Tab" then
        insertSymbol("    ")
      else
        insertSymbol(symbol)
      end
    end
  })
end

local divider = View(activity)
divider.setBackgroundColor(PANEL_LINE)
local dividerParams = LinearLayout.LayoutParams(dp(1), dp(18))
dividerParams.leftMargin = dp(6)
dividerParams.rightMargin = dp(6)
strip.addView(divider, dividerParams)

root.addView(stripScroll, LinearLayout.LayoutParams(-1, -2))

-- ===== 底部状态栏 =====
local statusBar = LinearLayout(activity)
statusBar.setOrientation(LinearLayout.HORIZONTAL)
statusBar.setGravity(Gravity.CENTER_VERTICAL)
statusBar.setBackgroundColor(PANEL_DEEP)
statusBar.setPadding(dp(10), dp(2), dp(8), dp(3))

local statusText = TextView(activity)
statusText.setTextSize(11)
statusText.setTextColor(TEXT_MUTED)
statusBar.addView(statusText, LinearLayout.LayoutParams(0, -2, 1))

languageText = TextView(activity)
languageText.setTextSize(11)
languageText.setTextColor(TEXT_MUTED)
languageText.setPadding(dp(7), 0, dp(7), 0)
languageText.setText(languageName)
statusBar.addView(languageText, LinearLayout.LayoutParams(-2, -2))

local dirtyText = TextView(activity)
dirtyText.setTextSize(11)
dirtyText.setTextColor(ACCENT)
statusBar.addView(dirtyText, LinearLayout.LayoutParams(-2, -2))

root.addView(statusBar, LinearLayout.LayoutParams(-1, -2))

-- 高亮只按当前文件后缀自动识别，不提供手动切换
local function applyAutoLanguage()
  languageId = EditorLanguage.detect(filePath)
  languageName = EditorLanguage.displayName(languageId)
  pcall(function()
    EditorLanguage.applyById(editor, languageId)
  end)
  if languageText then
    languageText.setText(languageName)
  end
end

applyAutoLanguage()
applyEditorColors(darkMode)

-- ===== 保存与状态 =====
local function currentText()
  local ok, value = pcall(function()
    return tostring(editor.getText().toString())
  end)
  if ok and value then
    return value
  end
  return ""
end

local function inputText(input)
  return tostring(input.getText().toString())
end

local function lineCount(text)
  local _, count = text:gsub("\n", "")
  return count + 1
end

local function isDirty()
  return currentText() ~= savedText
end

local cacheCaret = -1
local cacheLength = -1
local cacheLine = 1
local cacheColumn = 1

refreshStatus = function()
  local text = currentText()
  local caret = editor.getSelectionEnd()
  local total = lineCount(text)
  if caret ~= cacheCaret or #text ~= cacheLength then
    local start = 0
    pcall(function()
      start = TextUtil.lastIndexOf(text, "\n", caret - 1) + 1
    end)
    cacheColumn = caret - start + 1
    local prefix = tostring(TextUtil.substring(text, 0, start))
    local _, count = prefix:gsub("\n", "")
    cacheLine = count + 1
    cacheCaret = caret
    cacheLength = #text
  end
  local line = cacheLine
  local column = cacheColumn
  statusText.setText("行 " .. line .. "/" .. total .. " · 列 " .. column .. " · " .. TextUtil.length(text) .. " 字符")
  if text == savedText then
    dirtyText.setText("已保存")
    dirtyText.setTextColor(SUCCESS_TEXT)
    titleText.setText(fileName)
  else
    dirtyText.setText("未保存")
    dirtyText.setTextColor(ACCENT)
    titleText.setText(fileName .. " ●")
  end
end

local function markSaved()
  savedText = currentText()
  refreshStatus()
end

local function doSave()
  local content = currentText()
  if not writeFile(filePath, content) then
    toast("保存失败，请检查存储权限")
    return false
  end
  savedText = content
  refreshStatus()
  toast("已保存 " .. fileName)
  return true
end

-- ===== 保存前智能审计 =====
local auditDialogShowing = false
local lastRepair = nil

local function patternEscape(value)
  return (tostring(value or ""):gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

local function projectRootForEditor()
  local root = nil
  pcall(function()
    root = activity.getLuaExtDir("project")
  end)
  if not root or root == "" then
    local parent = File(filePath).getParentFile()
    return parent and parent.getAbsolutePath() or filePath
  end
  root = tostring(root):gsub("\\", "/"):gsub("/+$", "")
  local normalized = tostring(filePath):gsub("\\", "/")
  local relative = normalized:match("^" .. patternEscape(root) .. "/([^/]+)")
  if relative then
    return root .. "/" .. relative
  end
  local parent = File(filePath).getParentFile()
  return parent and parent.getAbsolutePath() or filePath
end

local function auditCurrentFile()
  if not tostring(filePath):lower():match("%.lua$") then
    return nil
  end
  local ok, report = pcall(function()
    return lint.audit(currentText(), {
      file = filePath,
      projectRoot = projectRootForEditor(),
    })
  end)
  if not ok or type(report) ~= "table" then
    return nil
  end
  return report
end

local function auditMessage(report)
  local lines = {}
  local total = #report.issues
  local maxLines = 9
  lines[#lines + 1] = "检测到 " .. total .. " 个问题："
  for index, issue in ipairs(report.issues) do
    if index > maxLines then
      break
    end
    local label = "提示"
    if issue.severity == "error" then
      label = "错误"
    elseif issue.severity == "warning" then
      label = "警告"
    end
    lines[#lines + 1] = index .. ". 第 " .. tostring(issue.line or 0) .. " 行 · "
      .. label .. "：" .. tostring(issue.message or "")
  end
  if total > maxLines then
    lines[#lines + 1] = "还有 " .. (total - maxLines) .. " 条未展开。"
  end
  local actions = report.actions or {}
  if #actions > 0 then
    local safe = report.safeCount or 0
    local guided = report.guidedCount or 0
    lines[#lines + 1] = "其中 " .. #actions .. " 项可一键修复"
    if guided > 0 then
      lines[#lines + 1] = "安全项 " .. safe .. " 个，需确认项 " .. guided .. " 个。"
    else
      lines[#lines + 1] = "均为安全修复。"
    end
  else
    lines[#lines + 1] = "这些问题不会阻止保存，可以继续检查或仍然保存。"
  end
  return table.concat(lines, "\n")
end

local function showRepairPlan(report, commit)
  local actions = report.actions or {}
  if #actions == 0 then
    toast("没有可自动应用的修复项")
    return
  end

  local labels = {}
  for index, action in ipairs(actions) do
    local confidence = action.confidence == "safe" and "安全" or "需确认"
    labels[index] = index .. ". [" .. confidence .. "] " .. tostring(action.title or "修复")
      .. "\n" .. tostring(action.preview or "")
  end

  local content = LinearLayout(activity)
  content.setOrientation(LinearLayout.VERTICAL)
  content.setPadding(dp(20), dp(8), dp(20), dp(4))
  local boxes = {}
  for index, label in ipairs(labels) do
    local box = CheckBox(activity)
    box.setText(label)
    box.setTextSize(13)
    box.setChecked(true)
    box.setPadding(dp(4), dp(6), dp(4), dp(6))
    content.addView(box, LinearLayout.LayoutParams(-1, -2))
    boxes[index] = box
  end
  local scroll = ScrollView(activity)
  scroll.addView(content)

  local builder = MaterialAlertDialogBuilder(activity)
    .setTitle("一键修复")
    .setView(scroll)
    .setNegativeButton("取消", function()
      auditDialogShowing = false
    end)
    .setOnCancelListener(function()
      auditDialogShowing = false
    end)

  builder.setPositiveButton("应用并保存", function()
    local selected = {}
    for index, action in ipairs(actions) do
      if boxes[index] and boxes[index].isChecked() then
        selected[#selected + 1] = action
      end
    end
    if #selected == 0 then
      auditDialogShowing = false
      toast("请至少选择一项修复")
      return
    end

    local before = currentText()
    local ok, result = pcall(lint.applyRepair, before, report, { actions = selected })
    if not ok or type(result) ~= "table" then
      auditDialogShowing = false
      toast("修复执行失败，文件未改动")
      return
    end
    if not result.ok then
      auditDialogShowing = false
      local message = tostring(result.message or "修复未应用，文件保持原样")
      if result.report then
        message = message .. "\n\n" .. auditMessage(result.report)
      end
      MaterialAlertDialogBuilder(activity)
        .setTitle("修复未应用")
        .setMessage(message)
        .setPositiveButton("知道了", nil)
        .show()
      return
    end

    local changed = pcall(function()
      editor.setText(result.text)
    end)
    if not changed then
      auditDialogShowing = false
      toast("修复写入编辑器失败，文件未保存")
      return
    end
    lastRepair = {
      before = before,
      after = result.text,
    }
    local caret = editor.getSelectionEnd()
    local target = math.max(0, math.min(#result.text, caret + (#result.text - #before)))
    pcall(function()
      editor.setSelectionRange(target, target)
      editor.focusSelectionEnd()
    end)
    auditDialogShowing = false
    toast("已应用 " .. tostring(result.applied or #selected) .. " 处修改，正在保存")
    commit()
  end)

  builder.show()
end

local function saveWithAudit(commit)
  if auditDialogShowing then
    return false
  end
  local report = auditCurrentFile()
  if not report or (not report.hasErrors and not report.hasWarnings) then
    return commit()
  end

  auditDialogShowing = true
  local builder = MaterialAlertDialogBuilder(activity)
    .setTitle("保存前检查")
    .setMessage(auditMessage(report))
    .setNegativeButton("取消", function()
      auditDialogShowing = false
    end)
    .setOnCancelListener(function()
      auditDialogShowing = false
    end)

  local actions = report.actions or {}
  if #actions > 0 then
    builder.setPositiveButton("一键修复", function()
      auditDialogShowing = false
      showRepairPlan(report, commit)
    end)
    builder.setNeutralButton("仍然保存", function()
      auditDialogShowing = false
      commit()
    end)
  else
    builder.setPositiveButton("仍然保存", function()
      auditDialogShowing = false
      commit()
    end)
  end

  builder.show()
  return false
end

local function showLintReport()
  local report = auditCurrentFile()
  if not report then
    toast("代码检查目前只支持 Lua 文件")
    return
  end
  if #report.issues == 0 then
    toast("检查通过，没有发现问题")
    return
  end
  local builder = MaterialAlertDialogBuilder(activity)
    .setTitle("代码检查")
    .setMessage(auditMessage(report))
    .setPositiveButton("关闭", nil)
  if #(report.actions or {}) > 0 then
    builder.setNeutralButton("一键修复", function()
      showRepairPlan(report, doSave)
    end)
  end
  builder.show()
end

saveBtn.setOnClickListener(View.OnClickListener{
  onClick = function()
    saveWithAudit(doSave)
  end
})

-- ===== 查找替换逻辑 =====
local function selectRange(fromIndex, toIndex)
  pcall(function()
    editor.setSelectionRange(fromIndex, toIndex)
    editor.focusSelectionEnd()
  end)
end

local function countMatches(query)
  if query == "" then
    return 0
  end
  local text = currentText()
  local total = 0
  local from = 0
  while true do
    local index = TextUtil.indexOf(text, query, from)
    if index < 0 then
      break
    end
    total = total + 1
    from = index + TextUtil.length(query)
    if total > 9999 then
      break
    end
  end
  return total
end

local function updateCount()
  local query = inputText(queryInput)
  local total = countMatches(query)
  if query == "" then
    countText.setText("")
  else
    countText.setText(total .. " 处")
  end
end

queryInput.addTextChangedListener(TextWatcher{
  beforeTextChanged = function()
  end,
  onTextChanged = function()
  end,
  afterTextChanged = function()
    updateCount()
  end
})

local function findNextMatch()
  local query = inputText(queryInput)
  if query == "" then
    return
  end
  local text = currentText()
  local from = editor.getSelectionEnd()
  local index = TextUtil.indexOf(text, query, from)
  if index < 0 and from > 0 then
    index = TextUtil.indexOf(text, query, 0)
    if index >= 0 then
      toast("已回到开头")
    end
  end
  if index < 0 then
    toast("没有匹配内容")
    return
  end
  selectRange(index, index + TextUtil.length(query))
end

local function findPrevMatch()
  local query = inputText(queryInput)
  if query == "" then
    return
  end
  local text = currentText()
  local from = editor.getSelectionStart() - 1
  local index = -1
  if from > 0 then
    index = TextUtil.lastIndexOf(text, query, from)
  end
  if index < 0 and #text > 0 then
    index = TextUtil.lastIndexOf(text, query, TextUtil.length(text) - 1)
    if index >= 0 then
      toast("已到末尾")
    end
  end
  if index < 0 then
    toast("没有匹配内容")
    return
  end
  selectRange(index, index + TextUtil.length(query))
end

nextBtn.setOnClickListener(View.OnClickListener{
  onClick = function()
    findNextMatch()
  end
})

prevBtn.setOnClickListener(View.OnClickListener{
  onClick = function()
    findPrevMatch()
  end
})

closeBtn.setOnClickListener(View.OnClickListener{
  onClick = function()
    findPanel.setVisibility(View.GONE)
  end
})

local function replaceCurrent()
  local query = inputText(queryInput)
  if query == "" then
    return
  end
  local start = editor.getSelectionStart()
  local stop = editor.getSelectionEnd()
  local selected = tostring(TextUtil.substring(currentText(), start, stop))
  if selected ~= query then
    findNextMatch()
    return
  end
  pcall(function()
    editor.replaceText(start, stop, inputText(replaceInput))
  end)
  updateCount()
  findNextMatch()
end

local function replaceAll()
  local query = inputText(queryInput)
  if query == "" then
    return
  end
  local replacement = inputText(replaceInput)
  local total = 0
  local from = 0
  while total < 9999 do
    local text = currentText()
    local index = TextUtil.indexOf(text, query, from)
    if index < 0 then
      break
    end
    pcall(function()
      editor.replaceText(index, index + TextUtil.length(query), replacement)
    end)
    total = total + 1
    from = index + TextUtil.length(replacement)
    if TextUtil.length(replacement) == 0 and from <= index then
      break
    end
  end
  updateCount()
  if total == 0 then
    toast("没有匹配内容")
  else
    toast("已替换 " .. total .. " 处")
  end
end

replaceBtn.setOnClickListener(View.OnClickListener{
  onClick = function()
    replaceCurrent()
  end
})

replaceAllBtn.setOnClickListener(View.OnClickListener{
  onClick = function()
    replaceAll()
  end
})

local function toggleFind()
  if findPanel.getVisibility() == View.GONE then
    findPanel.setVisibility(View.VISIBLE)
    queryInput.requestFocus()
    updateCount()
  else
    findPanel.setVisibility(View.GONE)
  end
end

findBtn.setOnClickListener(View.OnClickListener{
  onClick = function()
    toggleFind()
  end
})

-- ===== 行操作 =====
local function caretLineBounds()
  local text = currentText()
  local caret = editor.getSelectionEnd()
  local startIndex = TextUtil.lastIndexOf(text, "\n", caret - 1) + 1
  local endIndex = TextUtil.indexOf(text, "\n", caret)
  if endIndex < 0 then
    endIndex = TextUtil.length(text)
  end
  return startIndex, endIndex
end

local function currentLineText()
  local startIndex, endIndex = caretLineBounds()
  return tostring(TextUtil.substring(currentText(), startIndex, endIndex))
end

local function duplicateLine()
  local text = currentText()
  local startIndex, endIndex = caretLineBounds()
  local line = tostring(TextUtil.substring(text, startIndex, endIndex))
  local caret = editor.getSelectionEnd()
  pcall(function()
    editor.insert(endIndex, "\n" .. line)
  end)
  pcall(function()
    editor.setSelection(caret + TextUtil.length(line) + 1)
  end)
  refreshStatus()
end

local function moveLine(offset)
  local text = currentText()
  local startIndex, endIndex = caretLineBounds()
  local line = tostring(TextUtil.substring(text, startIndex, endIndex))
  local caret = editor.getSelectionEnd()
  if offset < 0 then
    if startIndex == 0 then
      return
    end
    local prevStart = TextUtil.lastIndexOf(text, "\n", startIndex - 2) + 1
    local prevLine = tostring(TextUtil.substring(text, prevStart, startIndex - 1))
    local block = prevLine .. "\n" .. line
    pcall(function()
      editor.replaceText(prevStart, endIndex, line .. "\n" .. prevLine)
    end)
    pcall(function()
      editor.setSelection(prevStart + TextUtil.length(line) + (caret - startIndex))
    end)
  else
    if endIndex >= TextUtil.length(text) then
      return
    end
    local nextEnd = TextUtil.indexOf(text, "\n", endIndex + 1)
    if nextEnd < 0 then
      nextEnd = TextUtil.length(text)
    end
    local nextLine = tostring(TextUtil.substring(text, endIndex + 1, nextEnd))
    pcall(function()
      editor.replaceText(startIndex, nextEnd, nextLine .. "\n" .. line)
    end)
    pcall(function()
      editor.setSelection(startIndex + TextUtil.length(nextLine) + 1 + (caret - startIndex))
    end)
  end
  refreshStatus()
end

local function commentStyle()
  if languageId == "lua" then
    return "--", nil, nil
  elseif languageId == "python" or languageId == "ruby"
    or languageId == "shell" or languageId == "yaml"
    or languageId == "markdown" then
    return "#", nil, nil
  elseif languageId == "sql" then
    return "--", "/*", "*/"
  elseif languageId == "html" then
    return nil, "<!--", "-->"
  elseif languageId == "css" then
    return nil, "/*", "*/"
  elseif languageId == "json" then
    return nil, nil, nil
  end
  return "//", "/*", "*/"
end

local function selectedLineBounds()
  local text = currentText()
  local from = editor.getSelectionStart()
  local to = editor.getSelectionEnd()
  if to < from then
    from, to = to, from
  end
  local startIndex = TextUtil.lastIndexOf(text, "\n", from - 1) + 1
  local endIndex = TextUtil.indexOf(text, "\n", to)
  if endIndex < 0 then
    endIndex = TextUtil.length(text)
  end
  return startIndex, endIndex
end

local function toggleComment()
  local text = currentText()
  local startIndex, endIndex = selectedLineBounds()
  local selected = tostring(TextUtil.substring(text, startIndex, endIndex))
  local prefix, blockStart, blockEnd = commentStyle()

  if not prefix then
    if not blockStart or not blockEnd then
      toast(languageName .. " 不支持行注释")
      return
    end
    local body = selected
    if body:sub(1, #blockStart) == blockStart and body:sub(-#blockEnd) == blockEnd then
      body = body:sub(#blockStart + 1, #body - #blockEnd)
    else
      body = blockStart .. body .. blockEnd
    end
    pcall(function()
      editor.replaceText(startIndex, endIndex, body)
    end)
    refreshStatus()
    return
  end

  local lines = {}
  local allPrefix = true
  local hasBody = false
  for line in (selected .. "\n"):gmatch("(.-)\n") do
    local indent = line:match("^%s*") or ""
    local body = line:sub(#indent + 1)
    if body ~= "" then
      hasBody = true
      if body:sub(1, #prefix) ~= prefix then
        allPrefix = false
      end
    end
    lines[#lines + 1] = line
  end
  if not hasBody then
    return
  end

  local result = {}
  for index = 1, #lines do
    local line = lines[index]
    local indent = line:match("^%s*") or ""
    local body = line:sub(#indent + 1)
    if body == "" then
      result[index] = line
    elseif allPrefix then
      result[index] = indent .. body:sub(#prefix + 1)
    else
      result[index] = indent .. prefix .. body
    end
  end
  pcall(function()
    editor.replaceText(startIndex, endIndex, table.concat(result, "\n"))
  end)
  refreshStatus()
end

-- ===== 菜单 =====
local MENU_ITEMS = {
  { name = "跳转行", action = "goto" },
  { name = "查找替换", action = "find" },
  { name = "撤销", action = "undo" },
  { name = "重做", action = "redo" },
  { name = "格式化代码", action = "format" },
  { name = "复制当前行", action = "duplicate" },
  { name = "注释 / 取消注释", action = "comment" },
  { name = "当前行上移", action = "up" },
  { name = "当前行下移", action = "down" },
  { name = "字号加大", action = "bigger" },
  { name = "字号减小", action = "smaller" },
  { name = "切换明暗主题", action = "theme" },
  { name = "撤销上次修复", action = "undoRepair" },
  { name = "代码检查", action = "lint" },
  { name = "另存为", action = "saveas" },
  { name = "文件信息", action = "info" }
}

local function menuActions(action)
  if action == "goto" then
    local box = LinearLayout(activity)
    box.setPadding(dp(18), dp(6), dp(18), 0)
    local input = EditText(activity)
    input.setHint("输入行号")
    input.setInputType(InputType.TYPE_CLASS_NUMBER)
    input.setTextSize(14)
    box.addView(input, LinearLayout.LayoutParams(-1, -2))
    MaterialAlertDialogBuilder(activity)
      .setTitle("跳转行")
      .setView(box)
      .setNegativeButton("取消", nil)
      .setPositiveButton("跳转", function()
        local number = tonumber(inputText(input))
        if number and number > 0 then
          editor.gotoLine(number)
          refreshStatus()
        end
      end)
      .show()
  elseif action == "find" then
    toggleFind()
  elseif action == "undo" then
    pcall(function()
      editor.undo()
    end)
    refreshStatus()
  elseif action == "redo" then
    pcall(function()
      editor.redo()
    end)
    refreshStatus()
  elseif action == "format" then
    if languageId ~= "lua" then
      toast("格式化目前只支持 Lua，当前是 " .. languageName)
      return
    end
    pcall(function()
      editor.format()
    end)
    refreshStatus()
  elseif action == "duplicate" then
    duplicateLine()
  elseif action == "comment" then
    toggleComment()
  elseif action == "up" then
    moveLine(-1)
  elseif action == "down" then
    moveLine(1)
  elseif action == "bigger" or action == "smaller" then
    local size = 15
    if action == "bigger" then
      size = math.min(28, math.floor(editor.getTextSize()) + 1)
    else
      size = math.max(12, math.floor(editor.getTextSize()) - 1)
    end
    editor.setTextSize(size)
    toast("字号 " .. size)
  elseif action == "theme" then
    darkMode = not darkMode
    applyEditorColors(darkMode)
    pcall(function()
      editor.respan()
    end)
  elseif action == "saveas" then
    local box = LinearLayout(activity)
    box.setOrientation(LinearLayout.VERTICAL)
    box.setPadding(dp(18), dp(6), dp(18), 0)
    local input = EditText(activity)
    input.setText(fileName)
    input.setTextSize(14)
    box.addView(input, LinearLayout.LayoutParams(-1, -2))
    MaterialAlertDialogBuilder(activity)
      .setTitle("另存为")
      .setView(box)
      .setNegativeButton("取消", nil)
      .setPositiveButton("保存", function()
        local name = inputText(input)
        if name == "" then
          return
        end
        local directory = File(filePath).getParentFile()
        local target = directory.getAbsolutePath() .. "/" .. name
        saveWithAudit(function()
          if writeFile(target, currentText()) then
            toast("已保存到 " .. name)
          else
            toast("保存失败")
          end
        end)
      end)
      .show()
  elseif action == "undoRepair" then
    if not lastRepair then
      toast("没有可撤销的修复")
      return
    end
    if currentText() ~= lastRepair.after then
      toast("修复后内容已变化，不能自动撤销")
      return
    end
    local before = lastRepair.before
    lastRepair = nil
    local ok = pcall(function()
      editor.setText(before)
    end)
    if not ok then
      toast("撤销修复失败")
      return
    end
    refreshStatus()
    toast("已撤销上次修复，尚未保存")
  elseif action == "lint" then
    showLintReport()
  elseif action == "info" then
    local file = File(filePath)
    local message = "路径：" .. filePath
      .. "\n语言：" .. languageName
      .. "\n大小：" .. file.length() .. " 字节"
      .. "\n修改时间：" .. os.date("%Y-%m-%d %H:%M:%S", math.floor(file.lastModified() / 1000))
      .. "\n行数：" .. lineCount(currentText())
      .. "\n字符数：" .. #currentText()
    MaterialAlertDialogBuilder(activity)
      .setTitle("文件信息")
      .setMessage(message)
      .setPositiveButton("知道了", nil)
      .show()
  end
end

moreBtn.setOnClickListener(View.OnClickListener{
  onClick = function()
    local names = {}
    for _, item in ipairs(MENU_ITEMS) do
      table.insert(names, item.name)
    end
    MaterialAlertDialogBuilder(activity)
      .setTitle(fileName)
      .setItems(names, function(_, which)
        local item = MENU_ITEMS[which + 1]
        if item then
          menuActions(item.action)
        end
      end)
      .setNegativeButton("取消", nil)
      .show()
  end
})

-- ===== 退出确认 =====
local exitDialogShowing = false
local function tryExit()
  if not isDirty() then
    activity.finish()
    return
  end
  if exitDialogShowing then
    return
  end
  exitDialogShowing = true
  MaterialAlertDialogBuilder(activity)
    .setTitle("还有修改未保存")
    .setMessage("退出后这次修改会丢失，确定要退出吗？")
    .setPositiveButton("保存并退出", function()
      exitDialogShowing = false
      saveWithAudit(function()
        if doSave() then
          activity.finish()
        end
      end)
    end)
    .setNeutralButton("直接退出", function()
      exitDialogShowing = false
      activity.finish()
    end)
    .setNegativeButton("取消", function()
      exitDialogShowing = false
    end)
    .setOnCancelListener(function()
      exitDialogShowing = false
    end)
    .show()
end

backBtn.setOnClickListener(View.OnClickListener{
  onClick = function()
    tryExit()
  end
})

-- 系统返回与手势返回统一交给守卫，未保存时先弹确认
pcall(function()
  local BackGuard = luajava.bindClass("com.mini.luaxplus.BackGuard")
  BackGuard.install(activity)
  BackGuard.setHandler(activity, luajava.new(luajava.bindClass("java.lang.Runnable"), {
    run = function()
      tryExit()
    end
  }))
end)

-- ===== 状态刷新 =====
refreshStatus()

local alive = true
local handler = Handler(Looper.getMainLooper())
local tick = nil
tick = function()
  if not alive then
    return
  end
  pcall(function()
    if activity.isFinishing() then
      alive = false
      return
    end
    refreshStatus()
  end)
  handler.postDelayed(tick, 700)
end
handler.postDelayed(tick, 400)

function onDestroy()
  alive = false
  pcall(function()
    handler.removeCallbacksAndMessages(nil)
  end)
end

