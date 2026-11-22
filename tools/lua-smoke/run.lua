-- JavaAPI 页面的严格契约测试。
--
-- 目的不是复刻 Android，而是把 LuaJava 的方法边界守死：
--   * Java 的零参数方法如果被 Lua 冒号调用（多传 self），这里直接失败；
--   * 页面加载、搜索、类点击、详情、成员搜索、复制都要跑一遍；
--   * 不依赖设备，可在构建和 CI 里快速执行。

package.preload["import"] = function()
  return {}
end
function import() end

local function fail(message)
  error("[lua-smoke] " .. message, 2)
end

local function expect(condition, message)
  if not condition then
    fail(message)
  end
end

local allEdits = {}
local allLists = {}
local allDialogs = {}
local allAdapters = {}
local toastMessages = {}
local clipboardValues = {}

local makeWindow

local function view()
  local o = {}
  o.children = {}
  o.addView = function(child, params)
    o.children[#o.children + 1] = { child, params }
  end
  o.removeView = function(child)
    o.removed = child
  end
  o.getChildCount = function()
    return #o.children
  end
  o.getChildAt = function(index)
    return o.children[index + 1] and o.children[index + 1][1]
  end
  o.setPadding = function() end
  o.setVisibility = function(value)
    o.visibility = value
  end
  o.setText = function(value)
    o.text = tostring(value)
    if o.listener and o.listener.afterTextChanged then
      o.listener.afterTextChanged(o.text)
    end
  end
  o.getText = function()
    return {
      toString = function()
        return o.text or ""
      end,
    }
  end
  o.setTextSize = function() end
  o.setTextColor = function() end
  o.setHint = function(value)
    o.hint = value
  end
  o.setHintTextColor = function() end
  o.setSingleLine = function() end
  o.setBackgroundColor = function() end
  o.setCacheColorHint = function() end
  o.setDivider = function() end
  o.setDividerHeight = function() end
  o.setFastScrollEnabled = function() end
  o.setVerticalScrollBarEnabled = function() end
  o.setAdapter = function(adapter)
    o.adapter = adapter
  end
  o.setEllipsize = function() end
  o.setIncludeFontPadding = function() end
  o.setTypeface = function() end
  o.setGravity = function() end
  o.setOrientation = function() end
  o.setBackground = function() end
  o.setOnClickListener = function(listener)
    o.click = listener.onClick or listener
  end
  o.requestFocus = function() end
  o.addTextChangedListener = function(listener)
    o.listener = listener
  end
  o.getWindowToken = function()
    return 1
  end
  o.show = function() end
  o.dismiss = function() end
  o.requestWindowFeature = function() end
  o.setContentView = function(content, params)
    o.content = content
    o.contentParams = params
  end
  o.setCanceledOnTouchOutside = function() end
  o.setOnDismissListener = function(listener)
    o.dismissListener = listener
  end
  o.getWindow = function()
    return makeWindow()
  end
  return o
end

makeWindow = function()
  local window = {}
  window.addFlags = function() end
  window.clearFlags = function() end
  window.setBackgroundDrawable = function() end
  window.setLayout = function() end
  window.setStatusBarColor = function() end
  window.setNavigationBarColor = function() end
  window.getDecorView = function()
    return { getWindowToken = function() return 1 end }
  end
  return window
end

TextView = function() return view() end
EditText = function()
  local edit = view()
  allEdits[#allEdits + 1] = edit
  return edit
end
ImageView = function() return view() end
ListView = function()
  local list = view()
  allLists[#allLists + 1] = list
  return list
end
FrameLayout = setmetatable({
  LayoutParams = function(width, height, gravity)
    return { width = width, height = height, gravity = gravity }
  end,
}, { __call = function() return view() end })
LinearLayout = setmetatable({
  HORIZONTAL = 0,
  VERTICAL = 1,
  LayoutParams = function(width, height, weight)
    return { width = width, height = height, weight = weight }
  end,
}, { __call = function() return view() end })
View = setmetatable({
  VISIBLE = 0,
  GONE = 8,
  OnClickListener = function(listener)
    return listener
  end,
}, { __call = function() return view() end })
Gravity = { CENTER = 17, CENTER_VERTICAL = 16, END = 5 }
TextUtils = { TruncateAt = { END = 2 } }
Typeface = { NORMAL = 0, create = function() return {} end }
ColorDrawable = function(color) return { color = color } end

-- Java 数组是 0 基，Lua 的 # 需要 __len 才能拿到真实长度。
local function javaArray(items)
  local out = {}
  for index, value in ipairs(items) do
    out[index - 1] = value
  end
  return setmetatable(out, {
    __len = function()
      return #items
    end,
  })
end

-- 关键：零参数 Java 方法收到多余参数必须报错。
-- 这样页面里一旦写成 obj:getName()，契约测试就会在构建阶段失败。
local function javaZero(label, fn)
  return function(...)
    local count = select("#", ...)
    if count ~= 0 then
      error(("[lua-smoke] Java method %s expected 0 args, got %d"):format(label, count), 2)
    end
    return fn()
  end
end

local strictProbe = javaZero("Method.getName", function() return "probe" end)
local probeOk = pcall(function() return strictProbe:getName() end)
expect(not probeOk, "严格 mock 自身失效：没有拦住冒号调用")

local function fakeType(name)
  return {
    getName = javaZero("Class.getName", function() return name end),
  }
end

local function fakeMethod(name, returnType, parameterTypes)
  return {
    getName = javaZero("Method.getName", function() return name end),
    getReturnType = javaZero("Method.getReturnType", function() return fakeType(returnType) end),
    getParameterTypes = javaZero("Method.getParameterTypes", function()
      local types = {}
      for _, typeName in ipairs(parameterTypes or {}) do
        types[#types + 1] = fakeType(typeName)
      end
      return javaArray(types)
    end),
  }
end

local function fakeField(name, typeName)
  return {
    getName = javaZero("Field.getName", function() return name end),
    getType = javaZero("Field.getType", function() return fakeType(typeName) end),
  }
end

local function fakeClass(name)
  local methods = javaArray({
    fakeMethod("setVisibility", "void", { "int" }),
    fakeMethod("setOnClickListener", "void", { "android.view.View$OnClickListener" }),
    fakeMethod("getVisibility", "int", {}),
  })
  local constructors = javaArray({
    {
      getParameterTypes = javaZero("Constructor.getParameterTypes", function()
        return javaArray({})
      end),
    },
  })
  return {
    getName = javaZero("Class.getName", function() return name end),
    getSuperclass = javaZero("Class.getSuperclass", function()
      return fakeClass("java.lang.Object")
    end),
    getConstructors = javaZero("Class.getConstructors", function() return constructors end),
    getMethods = javaZero("Class.getMethods", function() return methods end),
    getFields = javaZero("Class.getFields", function()
      return javaArray({ fakeField("VISIBLE", "int") })
    end),
  }
end

local failClass = nil
luajava = {
  bindClass = function(name)
    if name == failClass then
      return nil
    end
    if name == "java.lang.Runnable" then
      return {}
    end
    if name == "android.view.WindowManager$LayoutParams" then
      return {
        FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS = 1,
        FLAG_TRANSLUCENT_STATUS = 2,
        FLAG_TRANSLUCENT_NAVIGATION = 4,
      }
    end
    return fakeClass(name)
  end,
  new = function(_, value)
    return value
  end,
}

activity = {
  INPUT_METHOD_SERVICE = "input",
  CLIPBOARD_SERVICE = "clip",
  getResources = function()
    return {
      getDisplayMetrics = function() return { density = 2 } end,
      getConfiguration = function() return { uiMode = 0 } end,
    }
  end,
  getSystemService = function()
    return {
      hideSoftInputFromWindow = function() end,
      setPrimaryClip = function(value)
        clipboardValues[#clipboardValues + 1] = value
      end,
    }
  end,
  getWindow = function()
    return {
      getDecorView = function()
        return { getWindowToken = function() return 1 end }
      end,
    }
  end,
  setTheme = function() end,
  setContentView = function() end,
  getPackageName = function() return "com.mini.luaxplus" end,
}

ClipData = {
  newPlainText = function(_, text)
    return text
  end,
}
Toast = {
  LENGTH_SHORT = 0,
  makeText = function(_, text)
    toastMessages[#toastMessages + 1] = text
    return { show = function() end }
  end,
}
Handler = function()
  return {
    removeCallbacks = function() end,
    postDelayed = function(fn) fn.run() end,
  }
end
Looper = { getMainLooper = function() return {} end }
DialogInterface = { OnDismissListener = function(listener) return listener end }
Window = { FEATURE_NO_TITLE = 1 }
AppCompatDialog = function()
  local dialog = view()
  allDialogs[#allDialogs + 1] = dialog
  dialog.setContentView = function(content, params)
    dialog.content = content
    dialog.contentParams = params
  end
  dialog.show = function()
    dialog.shown = true
  end
  dialog.dismiss = function()
    dialog.dismissed = true
    if dialog.dismissListener and dialog.dismissListener.onDismiss then
      dialog.dismissListener.onDismiss()
    end
  end
  return dialog
end
LuaAdapter = function(_, layout)
  local adapter = {
    layout = layout,
    rows = {},
  }
  adapter.add = function(row)
    adapter.rows[#adapter.rows + 1] = row
  end
  allAdapters[#allAdapters + 1] = adapter
  return adapter
end

autotheme = function() return 1 end
classitem = { id = "classitem" }
memberitem = { id = "memberitem" }

package.preload["luaxplus.theme"] = function()
  return {
    colors = {
      paper = 0xFFF7F1E6,
      card = 0xFFFFFDF8,
      ink = 0xFF1C2B3A,
      muted = 0xFF5F6F7C,
      mutedLight = 0xFF9FB0BA,
      line = 0xFFE6DBC8,
      accent = 0xFF0F9E97,
    },
    install = function(ui) return ui end,
    apply = function() end,
  }
end

package.preload["luaxplus.icons"] = function()
  return {
    has = function() return true end,
    drawable = function() return 1 end,
    contrast = function() return 0xFF1C2B3A end,
    view = function(_, spec)
      local icon = view()
      icon.iconSize = spec and spec.size
      icon.setColorFilter = function() end
      return icon
    end,
    chip = function()
      return view()
    end,
    button = function()
      return view()
    end,
  }
end

package.preload["luaxplus.ui"] = function()
  local page = view()
  page.root = page
  page.scroll = view()
  page.show = function()
    page.shown = true
  end
  return {
    defineTheme = function() end,
    useTheme = function() end,
    page = function() return page end,
    text = function(spec)
      local textView = view()
      textView.setText(spec and spec.text or "")
      return textView
    end,
    surface = function(_, content)
      local box = view()
      if content then
        content(box)
      end
      return box
    end,
    empty = function() return view() end,
  }
end

package.preload["android"] = function()
  return {
    "android.view.View",
    "android.view.View",
  }
end

package.preload["androidXAndMaterialClasses"] = function()
  return {
    "androidx.appcompat.widget.AppCompatTextView",
    "androidx.core.internal.package-info",
  }
end

local root = arg[1] or "."
local pageFile = os.getenv("JAVAAPI_PAGE") or (root .. "/app/src/main/assets/javaapi/main.lua")
local chunk = assert(loadfile(pageFile))
chunk()
print("[lua-smoke] 页面加载通过")

expect(#allLists == 1, "类列表没有创建")
local classList = allLists[1]
expect(classList.adapter and #classList.adapter.rows == 2,
  "类索引数量不对，期望 2 个类")
expect(#allEdits == 1, "类搜索框没有创建")
local classSearch = allEdits[1]

local function classRows()
  return classList.adapter and classList.adapter.rows or {}
end

classSearch.setText("android.view.View")
expect(#classRows() == 1, "类搜索完整类名结果数量不对")

classSearch.setText("zzzz")
expect(#classRows() == 0, "类搜索空结果没有生效")

classSearch.setText("ANDROID.VIEW.VIEW")
expect(#classRows() == 1, "类搜索应忽略大小写")

classSearch.setText("")
expect(#classRows() == 2, "清空类搜索后没有恢复全量列表")
print("[lua-smoke] 类搜索通过")

local viewClassIndex = 2
local clipboardBefore = #clipboardValues
classList.onItemLongClick(classList, nil, 0, viewClassIndex)
expect(#clipboardValues == clipboardBefore + 1, "类长按没有写入剪贴板")
expect(clipboardValues[#clipboardValues] == "android.view.View",
  "类长按复制的不是完整类名")

failClass = "android.view.View"
local dialogCount = #allDialogs
classList.onItemClick(classList, nil, 0, viewClassIndex)
expect(#allDialogs == dialogCount, "类加载失败时不应打开详情")
expect(toastMessages[#toastMessages] and toastMessages[#toastMessages]:find("无法加载"),
  "类加载失败没有提示")
toastMessages = {}
failClass = nil
print("[lua-smoke] 类加载失败保护通过")

classList.onItemClick(classList, nil, 0, viewClassIndex)
expect(#allDialogs == 1, "类点击没有打开详情")
local dialog = allDialogs[1]
expect(dialog.content, "详情弹窗没有内容")
expect(#allLists == 2, "详情成员列表没有创建")
local memberList = allLists[2]
expect(memberList.adapter and #memberList.adapter.rows >= 5,
  "详情成员列表为空")
print("[lua-smoke] 类点击与详情构建通过")

clipboardBefore = #clipboardValues
memberList.onItemLongClick(memberList, nil, 0, 1)
expect(#clipboardValues == clipboardBefore + 1, "成员长按没有写入剪贴板")
expect(clipboardValues[#clipboardValues] ~= "", "成员长按复制内容为空")
print("[lua-smoke] 成员长按通过")

expect(#allEdits == 2, "详情搜索框没有创建")
local memberSearch = allEdits[2]
memberSearch.setText("get")
expect(#memberList.adapter.rows > 0, "详情搜索 get 没有结果")

memberSearch.setText("setOnClick")
expect(#memberList.adapter.rows > 0, "详情搜索事件没有结果")

memberSearch.setText("VISIBLE")
expect(#memberList.adapter.rows > 0, "详情搜索字段没有结果")

memberSearch.setText("zzzz")
expect(#memberList.adapter.rows == 0, "详情搜索空结果没有生效")

memberSearch.setText("")
expect(#memberList.adapter.rows >= 5, "清空详情搜索后没有恢复全部成员")
print("[lua-smoke] 详情搜索通过")

dialog.dismiss()
expect(dialog.dismissed, "详情弹窗没有关闭")

classList.onItemClick(classList, nil, 0, viewClassIndex)
expect(#allDialogs == 2, "关闭后无法重新打开详情")
expect(allDialogs[2].content, "重新打开的详情没有内容")
allDialogs[2].dismiss()
print("[lua-smoke] 详情关闭与重开通过")

print("[lua-smoke] 全部通过")
