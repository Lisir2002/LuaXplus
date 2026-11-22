require "import"
import "android.widget.*"
import "android.view.*"
import "android.app.*"
import "android.os.*"
import "android.graphics.*"
import "android.graphics.drawable.ColorDrawable"
import "android.text.*"
import "android.content.*"
import "androidx.appcompat.app.AppCompatDialog"
import "autotheme"
import "classitem"
import "memberitem"

activity.setTheme(autotheme())

local ui = require "luaxplus.ui"
local icons = require "luaxplus.icons"
local theme = require "luaxplus.theme"
theme.install(ui, "light")

local C = theme.colors
local density = activity.getResources().getDisplayMetrics().density

local function dp(value)
  return math.floor(value * density + 0.5)
end

local function textView(text, size, color, bold)
  local view = TextView(activity)
  view.setText(tostring(text or ""))
  view.setTextSize(size)
  view.setTextColor(color)
  if bold then
    pcall(function()
      view.setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL))
    end)
  end
  view.setIncludeFontPadding(false)
  return view
end

local function getText(edit)
  local ok, value = pcall(function()
    return edit.getText().toString()
  end)
  return ok and tostring(value) or ""
end

local function hideKeyboard()
  pcall(function()
    local imm = activity.getSystemService(activity.INPUT_METHOD_SERVICE)
    imm.hideSoftInputFromWindow(activity.getWindow().getDecorView().getWindowToken(), 0)
  end)
end

local clipboard = activity.getSystemService(activity.CLIPBOARD_SERVICE)
local function copyText(value)
  value = tostring(value or "")
  if value == "" then
    return
  end
  local ok = pcall(function()
    clipboard.setPrimaryClip(ClipData.newPlainText("JavaAPI", value))
  end)
  Toast.makeText(activity, ok and ("已复制：" .. value) or "复制失败", Toast.LENGTH_SHORT).show()
end

-- 读取两类本地索引，去掉重复项和不可加载的 package-info 占位类。
local classEntries = {}
local classIndex = {}
local function appendClasses(moduleName)
  local ok, list_ = pcall(require, moduleName)
  if not ok or type(list_) ~= "table" then
    return
  end
  for index = 1, #list_ do
    local name = list_[index]
    if type(name) == "string" and name ~= ""
        and not name:match("%.package%-info$")
        and not classIndex[name] then
      local simple = name:match("([^%.]+)$") or name
      simple = simple:gsub("%$", ".")
      local package = name:match("^(.*)%.[^%.]+$") or ""
      local entry = {
        name = name,
        simple = simple,
        package = package,
        search = (name .. " " .. simple .. " " .. package):lower(),
      }
      classIndex[name] = entry
      classEntries[#classEntries + 1] = entry
    end
  end
end

appendClasses("android")
appendClasses("androidXAndMaterialClasses")

table.sort(classEntries, function(a, b)
  local left, right = a.simple:lower(), b.simple:lower()
  if left == right then
    return a.name < b.name
  end
  return left < right
end)

local function filterClasses(query)
  query = query:lower():gsub("^%s+", ""):gsub("%s+$", "")
  if query == "" then
    return classEntries
  end
  local tokens = {}
  for token in query:gmatch("%S+") do
    tokens[#tokens + 1] = token
  end
  local result = {}
  for index = 1, #classEntries do
    local entry = classEntries[index]
    local matched = true
    for tokenIndex = 1, #tokens do
      if not entry.search:find(tokens[tokenIndex], 1, true) then
        matched = false
        break
      end
    end
    if matched then
      result[#result + 1] = entry
    end
  end
  return result
end

local function makeSearch(hint, onChange)
  local input = EditText(activity)
  input.setSingleLine(true)
  input.setTextSize(15)
  input.setTextColor(C.ink)
  input.setHintTextColor(C.muted)
  input.setHint(hint)
  input.setBackgroundColor(0x00000000)
  input.setPadding(0, 0, 0, 0)

  local clear = icons.view("close", { size = 15, color = C.muted })
  clear.setVisibility(View.GONE)
  clear.setPadding(dp(6), 0, dp(6), 0)

  local glyph = icons.view("search", { size = 17, color = C.muted })

  local box = ui.surface({
    background = C.card,
    stroke = C.line,
    radius = "10px",
    padding = "8px",
    elevation = false,
  }, function(body_)
    body_.setOrientation(LinearLayout.HORIZONTAL)
    body_.setGravity(Gravity.CENTER_VERTICAL)
    body_.addView(glyph, LinearLayout.LayoutParams(dp(24), dp(36)))
    body_.addView(input, LinearLayout.LayoutParams(0, dp(36), 1))
    body_.addView(clear, LinearLayout.LayoutParams(dp(32), dp(36)))
  end)

  clear.setOnClickListener(View.OnClickListener{
    onClick = function()
      input.setText("")
      input.requestFocus()
    end
  })
  input.addTextChangedListener{
    afterTextChanged = function(editable)
      local value = tostring(editable)
      clear.setVisibility(#value > 0 and View.VISIBLE or View.GONE)
      if onChange then
        onChange(value)
      end
    end
  }
  return { view = box, input = input, clear = clear }
end

local page = ui.page({
  title = "Java API 浏览器",
  subtitle = "类、方法、字段与事件 · 本地离线索引",
  back = true,
  largeTitle = false,
})
page.root.removeView(page.scroll)

local body = LinearLayout(activity)
body.setOrientation(LinearLayout.VERTICAL)
body.setPadding(dp(16), dp(8), dp(16), 0)
page.root.addView(body, LinearLayout.LayoutParams(-1, 0, 1))

local onClassSearchChanged
local search = makeSearch("搜索类名，例如 TextView、android.view、Material", function()
  if onClassSearchChanged then
    onClassSearchChanged()
  end
end)

local meta = LinearLayout(activity)
meta.setOrientation(LinearLayout.HORIZONTAL)
meta.setGravity(Gravity.CENTER_VERTICAL)
meta.setPadding(0, dp(8), 0, dp(4))
local countLabel = ui.text({ text = "", type = "footnote", color = C.muted })
local hintLabel = ui.text({ text = "长按复制类名", type = "footnote", color = C.mutedLight })
meta.addView(countLabel, LinearLayout.LayoutParams(0, -2, 1))
meta.addView(hintLabel)

body.addView(search.view, LinearLayout.LayoutParams(-1, -2))
body.addView(meta, LinearLayout.LayoutParams(-1, -2))

local listFrame = FrameLayout(activity)
local classList = ListView(activity)
classList.setBackgroundColor(C.paper)
classList.setCacheColorHint(C.paper)
classList.setDivider(ColorDrawable(C.line))
classList.setDividerHeight(1)
classList.setFastScrollEnabled(true)
classList.setVerticalScrollBarEnabled(false)
classList.setPadding(0, dp(2), 0, dp(16))
listFrame.addView(classList, FrameLayout.LayoutParams(-1, -1))

local empty = ui.empty({
  title = "没有匹配的类",
  message = "换个关键词，或试试完整包名，例如 android.view.View",
})
empty.setVisibility(View.GONE)
listFrame.addView(empty, FrameLayout.LayoutParams(-1, -2, Gravity.CENTER))
body.addView(listFrame, LinearLayout.LayoutParams(-1, 0, 1))

local currentClasses = {}
local function refreshClasses()
  local query = getText(search.input)
  local result = filterClasses(query)
  currentClasses = result
  local adapter = LuaAdapter(activity, classitem)
  for index = 1, #result do
    local entry = result[index]
    adapter.add({ title = entry.simple, subtitle = entry.name })
  end
  classList.setAdapter(adapter)
  if query == "" then
    countLabel.setText("共 " .. tostring(#classEntries) .. " 个类")
  else
    countLabel.setText("找到 " .. tostring(#result) .. " 个类")
  end
  empty.setVisibility(#result == 0 and View.VISIBLE or View.GONE)
end

local mainHandler = Handler(Looper.getMainLooper())
local classRefreshRunnable = luajava.new(luajava.bindClass("java.lang.Runnable"), {
  run = function()
    refreshClasses()
  end,
})
local function scheduleClassRefresh()
  mainHandler.removeCallbacks(classRefreshRunnable)
  mainHandler.postDelayed(classRefreshRunnable, 120)
end
onClassSearchChanged = scheduleClassRefresh

classList.onItemClick = function(list_, view_, position_, index_)
  local entry = currentClasses[index_]
  if not entry then
    return
  end
  hideKeyboard()
  local ok, class = pcall(luajava.bindClass, entry.name)
  if not ok or not class then
    Toast.makeText(activity, "当前运行环境无法加载这个类：" .. entry.name, Toast.LENGTH_SHORT).show()
    return
  end
  local detailOk, detailError = pcall(showClassDetail, entry, class)
  if not detailOk then
    print("JavaAPI detail error: " .. tostring(detailError))
    Toast.makeText(activity, "详情加载失败：" .. entry.simple, Toast.LENGTH_SHORT).show()
  end
end

classList.onItemLongClick = function(list_, view_, position_, index_)
  local entry = currentClasses[index_]
  if entry then
    copyText(entry.name)
  end
  return true
end

refreshClasses()

-- 把反射对象转换成短签名，避免直接使用 tostring 时出现 $Proxy 等内部格式。
local function typeName(value)
  if value == nil then
    return "?"
  end
  local ok, name = pcall(function()
    return value.getName()
  end)
  if not ok or not name then
    return tostring(value)
  end
  local dimensions = 0
  while name:sub(1, 1) == "[" do
    dimensions = dimensions + 1
    name = name:sub(2)
  end
  if name:sub(1, 1) == "L" and name:sub(-1) == ";" then
    name = name:sub(2, -2)
  elseif #name == 1 then
    local primitive = {
      I = "int", Z = "boolean", B = "byte", C = "char",
      S = "short", J = "long", F = "float", D = "double", V = "void",
    }
    name = primitive[name] or name
  end
  if dimensions > 0 then
    name = name .. string.rep("[]", dimensions)
  end
  return name
end

local function parameterNames(member)
  local result = {}
  local ok, types = pcall(function()
    return member.getParameterTypes()
  end)
  if ok and types then
    for index = 0, #types - 1 do
      result[#result + 1] = typeName(types[index])
    end
  end
  return result
end

local function methodTitle(method)
  local ok, returnType = pcall(function()
    return method.getReturnType()
  end)
  return typeName(ok and returnType or nil) .. " " .. method.getName()
    .. "(" .. table.concat(parameterNames(method), ", ") .. ")"
end

local function buildMembers(class, entry)
  local members = {}
  local seen = {}

  local function add(kind, title, subtitle, name)
    if not title or title == "" then
      return
    end
    local key = kind .. "\1" .. title
    if seen[key] then
      return
    end
    seen[key] = true
    members[#members + 1] = {
      kind = kind,
      title = title,
      subtitle = subtitle,
      name = name or title,
    }
  end

  local constructors = {}
  local ok, ctors = pcall(function()
    return class.getConstructors()
  end)
  if ok and ctors then
    for index = 0, #ctors - 1 do
      local ctor = ctors[index]
      constructors[#constructors + 1] = {
        title = "new " .. entry.simple .. "(" .. table.concat(parameterNames(ctor), ", ") .. ")",
        name = entry.simple,
      }
    end
  end
  table.sort(constructors, function(a, b)
    return a.title:lower() < b.title:lower()
  end)
  for index = 1, #constructors do
    local item = constructors[index]
    add("构造方法", item.title, "构造方法", item.name)
  end

  local methods = {}
  local methodOk, methodArray = pcall(function()
    return class.getMethods()
  end)
  if methodOk and methodArray then
    for index = 0, #methodArray - 1 do
      methods[#methods + 1] = methodArray[index]
    end
  end
  table.sort(methods, function(a, b)
    return tostring(a.getName()) < tostring(b.getName())
  end)

  local events = {}
  local getters = {}
  local setters = {}
  local allMethods = {}
  for index = 1, #methods do
    local method = methods[index]
    local name = method.getName()
    local parameters = parameterNames(method)
    local title = methodTitle(method)
    local returnType = ""
    pcall(function()
      returnType = typeName(method.getReturnType())
    end)

    local event = name:match("^setOn(.+)Listener$")
    if event then
      events[#events + 1] = {
        title = "on" .. event,
        subtitle = "事件 · " .. name,
        name = "on" .. event,
      }
    elseif name:match("^set%u") and #parameters == 1 then
      setters[#setters + 1] = {
        title = name .. "(" .. parameters[1] .. ")",
        name = name,
      }
    elseif (name:match("^get%u") or name:match("^is%u")) and #parameters == 0 then
      getters[#getters + 1] = {
        title = name .. "() : " .. returnType,
        name = name,
      }
    end

    allMethods[#allMethods + 1] = {
      title = title,
      name = name,
    }
  end

  local function appendGroup(group, kind, subtitle)
    table.sort(group, function(a, b)
      return a.title:lower() < b.title:lower()
    end)
    for index = 1, #group do
      local item = group[index]
      add(kind, item.title, item.subtitle or subtitle, item.name)
    end
  end

  appendGroup(events, "事件", "事件")
  appendGroup(getters, "getter", "getter")
  appendGroup(setters, "setter", "setter")

  local fields = {}
  local fieldOk, fieldArray = pcall(function()
    return class.getFields()
  end)
  if fieldOk and fieldArray then
    for index = 0, #fieldArray - 1 do
      local field = fieldArray[index]
      local fieldType = "?"
      pcall(function()
        fieldType = typeName(field.getType())
      end)
      fields[#fields + 1] = {
        title = fieldType .. " " .. field.getName(),
        name = field.getName(),
      }
    end
  end
  appendGroup(fields, "字段", "字段")
  appendGroup(allMethods, "方法", "方法")

  return members
end

local detailDialog = nil
function showClassDetail(entry, class)
  if detailDialog then
    pcall(function() detailDialog.dismiss() end)
  end

  local members = buildMembers(class, entry)
  local superName = ""
  pcall(function()
    local superclass = class.getSuperclass()
    if superclass then
      superName = superclass.getName()
    end
  end)

  local dialog = AppCompatDialog(activity, autotheme())
  pcall(function()
    dialog.requestWindowFeature(Window.FEATURE_NO_TITLE)
  end)
  dialog.setCanceledOnTouchOutside(true)

  local root = LinearLayout(activity)
  root.setOrientation(LinearLayout.VERTICAL)
  root.setBackgroundColor(C.paper)
  root.setPadding(dp(16), dp(10), dp(16), dp(8))

  local head = LinearLayout(activity)
  head.setOrientation(LinearLayout.HORIZONTAL)
  head.setGravity(Gravity.CENTER_VERTICAL)
  local titleBox = LinearLayout(activity)
  titleBox.setOrientation(LinearLayout.VERTICAL)
  local title = textView(entry.simple, 20, C.ink, true)
  title.setSingleLine(true)
  title.setEllipsize(TextUtils.TruncateAt.END)
  local fullName = textView(entry.name, 11.5, C.muted, false)
  fullName.setSingleLine(true)
  fullName.setEllipsize(TextUtils.TruncateAt.END)
  fullName.setPadding(0, dp(2), 0, 0)
  titleBox.addView(title)
  titleBox.addView(fullName)
  if superName ~= "" then
    local superLabel = textView("extends " .. superName, 11, C.mutedLight, false)
    superLabel.setSingleLine(true)
    superLabel.setEllipsize(TextUtils.TruncateAt.END)
    superLabel.setPadding(0, dp(2), 0, 0)
    titleBox.addView(superLabel)
  end
  head.addView(titleBox, LinearLayout.LayoutParams(0, -2, 1))

  local copyLink = textView("复制", 12, C.accent, true)
  copyLink.setPadding(dp(8), dp(6), dp(8), dp(6))
  copyLink.setOnClickListener(View.OnClickListener{
    onClick = function()
      copyText(entry.name)
    end
  })
  head.addView(copyLink)

  local close = icons.view("close", { size = 17, color = C.muted })
  close.setPadding(dp(8), dp(6), dp(8), dp(6))
  close.setOnClickListener(View.OnClickListener{
    onClick = function()
      dialog.dismiss()
    end
  })
  head.addView(close)
  root.addView(head, LinearLayout.LayoutParams(-1, -2))

  local memberMeta = LinearLayout(activity)
  memberMeta.setOrientation(LinearLayout.HORIZONTAL)
  memberMeta.setGravity(Gravity.CENTER_VERTICAL)
  memberMeta.setPadding(0, dp(8), 0, dp(4))
  local memberCount = ui.text({ text = "", type = "footnote", color = C.muted })
  local memberHint = ui.text({ text = "长按复制名称", type = "footnote", color = C.mutedLight })
  memberMeta.addView(memberCount, LinearLayout.LayoutParams(0, -2, 1))
  memberMeta.addView(memberHint)
  root.addView(memberMeta, LinearLayout.LayoutParams(-1, -2))

  local memberSearch
  local memberHandler = Handler(Looper.getMainLooper())
  local memberListFrame = FrameLayout(activity)
  local memberList = ListView(activity)
  memberList.setBackgroundColor(C.paper)
  memberList.setCacheColorHint(C.paper)
  memberList.setDivider(ColorDrawable(C.line))
  memberList.setDividerHeight(1)
  memberList.setFastScrollEnabled(true)
  memberList.setVerticalScrollBarEnabled(false)
  memberList.setPadding(0, dp(2), 0, dp(16))
  memberListFrame.addView(memberList, FrameLayout.LayoutParams(-1, -1))
  local memberEmpty = ui.empty({
    title = "没有匹配的成员",
    message = "换个关键词试试，或清空搜索查看全部",
  })
  memberEmpty.setVisibility(View.GONE)
  memberListFrame.addView(memberEmpty, FrameLayout.LayoutParams(-1, -2, Gravity.CENTER))

  local memberResults = members
  local memberRefreshRunnable
  local function refreshMembers()
    local query = getText(memberSearch.input)
    local result = {}
    if query == "" then
      result = members
    else
      local needle = query:lower()
      for index = 1, #members do
        local item = members[index]
        if item.title:lower():find(needle, 1, true)
            or item.subtitle:lower():find(needle, 1, true) then
          result[#result + 1] = item
        end
      end
    end
    memberResults = result
    local adapter = LuaAdapter(activity, memberitem)
    for index = 1, #result do
      adapter.add({ title = result[index].title, subtitle = result[index].subtitle })
    end
    memberList.setAdapter(adapter)
    memberCount.setText(tostring(#result) .. " 个成员")
    memberEmpty.setVisibility(#result == 0 and View.VISIBLE or View.GONE)
  end
  local function scheduleMemberRefresh()
    memberHandler.removeCallbacks(memberRefreshRunnable)
    memberHandler.postDelayed(memberRefreshRunnable, 120)
  end
  memberRefreshRunnable = luajava.new(luajava.bindClass("java.lang.Runnable"), {
    run = function()
      refreshMembers()
    end,
  })
  memberSearch = makeSearch("筛选方法、字段或事件", scheduleMemberRefresh)
  root.addView(memberSearch.view, LinearLayout.LayoutParams(-1, -2))

  memberList.onItemLongClick = function(list_, view_, position_, index_)
    local item = memberResults[index_]
    if item then
      copyText(item.name)
    end
    return true
  end

  root.addView(memberListFrame, LinearLayout.LayoutParams(-1, 0, 1))
  refreshMembers()

  dialog.setOnDismissListener(DialogInterface.OnDismissListener{
    onDismiss = function()
      memberHandler.removeCallbacks(memberRefreshRunnable)
      if detailDialog == dialog then
        detailDialog = nil
      end
    end,
  })

  dialog.setContentView(root, FrameLayout.LayoutParams(-1, -1))
  local window = dialog.getWindow()
  if window then
    window.setBackgroundDrawable(ColorDrawable(C.paper))
  end
  detailDialog = dialog
  dialog.show()
  pcall(function()
    theme.apply(dialog, { background = C.paper, dark = false })
  end)
  if window then
    pcall(function()
      window.setLayout(-1, -1)
    end)
  end
end

page:show()
