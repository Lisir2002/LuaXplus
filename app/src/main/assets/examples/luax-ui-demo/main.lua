require "import"
import "android.app.*"
import "android.os.*"
import "android.widget.*"
import "android.view.*"
import "android.graphics.Typeface"
import "android.graphics.drawable.*"

-- 官方示例：LuaX-UI 组件库全量展示
-- 说明：这个工程只使用公开的 ui 模块与普通 View，不修改任何原生 Lua 写法。

local ui = require "luaxplus.ui"
local dp = ui.dp

local TAB_TITLES = {"控件", "表单", "弹窗", "关于"}

local page
local tabBar
local currentTab = 1
local showTab
local buildShell

local function palette()
  return ui.palette()
end

local function toast(text)
  Toast.makeText(activity, text, Toast.LENGTH_SHORT).show()
end

local function heading(title, note)
  local box = LinearLayout(activity)
  box.setOrientation(LinearLayout.VERTICAL)
  box.setPadding(dp(4), dp(4), dp(4), dp(10))

  local titleView = TextView(activity)
  titleView.setText(title)
  titleView.setTextSize(29)
  titleView.setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL))
  titleView.setTextColor(palette().label)
  titleView.setIncludeFontPadding(false)
  box.addView(titleView)

  if note then
    local noteView = TextView(activity)
    noteView.setText(note)
    noteView.setTextSize(13)
    noteView.setTextColor(palette().secondary)
    noteView.setPadding(0, dp(6), 0, 0)
    box.addView(noteView)
  end
  return box
end

local function addButtonStack(items)
  local box = LinearLayout(activity)
  box.setOrientation(LinearLayout.VERTICAL)
  for index = 1, #items do
    local spec = items[index]
    local button = ui.button(spec)
    local params = LinearLayout.LayoutParams(-1, -2)
    if index > 1 then
      params.topMargin = dp(8)
    end
    box.addView(button, params)
  end
  return box
end

local function showInfo(title, message)
  ui.alert({
    title = title,
    message = message,
    actions = {
      { title = "知道了" },
    },
  })
end

-- ===== 一、控件 =====
local function buildControls()
  page:add(heading("控件", "分组列表、按钮、分段、卡片、头像、徽标与分割线"))

  page:add(ui.group("分组列表", {
    ui.row({
      icon = "W",
      iconBg = palette().blue,
      title = "Wi-Fi",
      subtitle = "已连接，信号良好",
      value = "Home",
      chevron = true,
      onClick = function()
        showInfo("Wi-Fi", "这一行演示图标、副标题、右侧值和箭头。")
      end,
    }),
    ui.row({
      icon = "B",
      iconBg = palette().green,
      title = "蓝牙",
      subtitle = "已开启",
      toggle = true,
      onToggle = function(state)
        toast("蓝牙：" .. (state and "开" or "关"))
      end,
    }),
    ui.row({
      icon = "N",
      iconBg = palette().orange,
      title = "通知",
      subtitle = "允许通知与提示",
      toggle = false,
      onToggle = function(state)
        toast("通知：" .. (state and "开" or "关"))
      end,
    }),
    ui.row({
      icon = "✓",
      iconBg = palette().blue,
      title = "选中状态",
      subtitle = "selected = true",
      selected = true,
    }),
    ui.row({
      title = "危险操作",
      subtitle = "destructive = true，点击会二次确认",
      destructive = true,
      chevron = true,
      onClick = function()
        ui.alert({
          title = "删除示例",
          message = "这是演示用的危险操作，不会真的删除任何文件。",
          actions = {
            { title = "取消", style = "cancel" },
            { title = "删除", style = "destructive", onClick = function()
              toast("已取消删除")
            end },
          },
        })
      end,
    }),
    ui.row({
      title = "禁用行",
      subtitle = "disabled = true",
      value = "不可用",
      disabled = true,
      chevron = true,
    }),
    ui.row({
      title = "自定义右侧",
      subtitle = "accessory 可以放任意 View",
      accessory = ui.badge("NEW", palette().blue),
      chevron = false,
    }),
    ui.row({
      title = "没有箭头",
      subtitle = "chevron = false",
      chevron = false,
      onClick = function()
        toast("整行仍然可以点击")
      end,
    }),
  }, "图标、副标题、值、开关、选中、危险、禁用和自定义右侧都在这一组。"))

  page:add(ui.card({
    title = "按钮样式",
    subtitle = "filled / tinted / gray / plain / destructive / 禁用",
  }, function(box)
    box.addView(addButtonStack({
      { text = "填充按钮", style = "filled", onClick = function() toast("filled") end },
      { text = "浅色按钮", style = "tinted", onClick = function() toast("tinted") end },
      { text = "灰色按钮", style = "gray", onClick = function() toast("gray") end },
      { text = "文字按钮", style = "plain", onClick = function() toast("plain") end },
      { text = "危险按钮", style = "destructive", onClick = function() toast("destructive") end },
      { text = "禁用按钮", style = "filled", enabled = false },
    }))
  end), 14)

  local segmentValue = TextView(activity)
  segmentValue.setTextSize(13)
  segmentValue.setTextColor(palette().secondary)
  segmentValue.setPadding(dp(4), dp(8), dp(4), 0)
  segmentValue.setText("当前选择：周")

  local segment = ui.segmented({
    items = { "日", "周", "月" },
    selected = 2,
    onChange = function(index, item)
      segmentValue.setText("当前选择：" .. tostring(item))
    end,
  })
  page:add(segment.view, 14)
  page:add(segmentValue, 0)

  page:add(ui.card({
    title = "卡片容器",
    subtitle = "标题、副标题和任意内容组合",
  }, function(box)
    local first = ui.row({
      icon = "i",
      iconBg = palette().blue,
      title = "卡片里的行",
      subtitle = "仍然使用同一套 row",
      chevron = true,
      onClick = function() toast("卡片内点击") end,
    })
    box.addView(first)
    box.addView(ui.divider(0))
    local second = ui.row({
      title = "分割线",
      subtitle = "divider 可以直接放进卡片",
      value = "OK",
      chevron = false,
    })
    box.addView(second)
  end), 14)

  local people = LinearLayout(activity)
  people.setOrientation(LinearLayout.HORIZONTAL)
  people.setGravity(Gravity.CENTER_VERTICAL)
  people.setPadding(dp(4), dp(8), dp(4), dp(8))
  people.addView(ui.avatar("L", palette().blue, 52))
  local gap1 = View(activity)
  people.addView(gap1, LinearLayout.LayoutParams(dp(10), 1))
  people.addView(ui.avatar("U", palette().green, 44))
  local gap2 = View(activity)
  people.addView(gap2, LinearLayout.LayoutParams(dp(10), 1))
  people.addView(ui.avatar("X", palette().orange, 44))
  local gap3 = View(activity)
  people.addView(gap3, LinearLayout.LayoutParams(dp(14), 1))
  people.addView(ui.badge("NEW", palette().blue))
  local gap4 = View(activity)
  people.addView(gap4, LinearLayout.LayoutParams(dp(6), 1))
  people.addView(ui.badge("HOT", palette().red))
  page:add(people, 8)

  page:add(ui.divider(16), 4)
  page:add(ui.spacer(8))
end

-- ===== 二、表单 =====
local COMPONENTS = {
  { title = "按钮", subtitle = "六种样式与禁用态", icon = "B", bg = "blue" },
  { title = "分组列表", subtitle = "row / group / 分割线", icon = "G", bg = "green" },
  { title = "表单字段", subtitle = "fieldRow / field / textArea", icon = "F", bg = "orange" },
  { title = "搜索栏", subtitle = "searchBar 实时过滤", icon = "S", bg = "blue" },
  { title = "分段控件", subtitle = "segmented 日 / 周 / 月", icon = "T", bg = "green" },
  { title = "弹窗", subtitle = "alert / actionSheet", icon = "A", bg = "red" },
  { title = "标签栏", subtitle = "tabBar 四个页签", icon = "N", bg = "blue" },
  { title = "空态与加载", subtitle = "empty / loading", icon = "E", bg = "orange" },
}

local function buildForms()
  page:add(heading("表单", "输入、搜索、分段、实时反馈与保存"))

  local nicknameHint = TextView(activity)
  local nickname = ui.fieldRow({
    label = "昵称",
    placeholder = "输入昵称",
    value = "LuaX",
    onChange = function(value)
      if value == "" then
        nicknameHint.setText("昵称不能为空")
      else
        nicknameHint.setText("正在输入：" .. value)
      end
    end,
  })
  nicknameHint.setTextSize(12)
  nicknameHint.setTextColor(palette().secondary)
  nicknameHint.setPadding(dp(4), dp(7), dp(4), 0)
  nicknameHint.setText("正在输入：LuaX")

  local phone = ui.fieldRow({
    label = "手机号",
    placeholder = "11 位手机号",
    phone = true,
  })

  local password = ui.fieldRow({
    label = "密码",
    placeholder = "输入密码",
    secure = true,
  })

  local email = ui.fieldRow({
    label = "邮箱",
    placeholder = "name@example.com",
    email = true,
  })

  local age = ui.fieldRow({
    label = "年龄",
    placeholder = "纯数字",
    numeric = true,
  })

  page:add(ui.group("账号字段", {
    nickname.view,
    phone.view,
    password.view,
    email.view,
    age.view,
  }, "fieldRow 适合一行一个字段；placeholder、secure、phone、email、numeric 都是可选参数。"))
  page:add(nicknameHint, 0)

  local emailField = ui.field({
    label = "邮箱地址",
    hint = "name@example.com",
    email = true,
    footer = "field 适合更宽松的输入区，下方可以带说明。",
  })
  page:add(emailField.view, 14)

  local bio = ui.textArea({
    label = "简介",
    hint = "写点什么…",
    lines = 4,
    footer = "textArea 是 field 的多行快捷写法。",
  })
  page:add(bio.view, 14)

  local searchResults = LinearLayout(activity)
  searchResults.setOrientation(LinearLayout.VERTICAL)

  local function renderSearch(keyword)
    searchResults.removeAllViews()
    local word = tostring(keyword or ""):lower()
    local matched = 0
    for index = 1, #COMPONENTS do
      local item = COMPONENTS[index]
      local text = (item.title .. " " .. item.subtitle):lower()
      if word == "" or text:find(word, 1, true) then
        matched = matched + 1
        local row = ui.row({
          icon = item.icon,
          iconBg = palette()[item.bg] or palette().blue,
          title = item.title,
          subtitle = item.subtitle,
          chevron = true,
          onClick = function()
            showInfo(item.title, item.subtitle)
          end,
        })
        local wrap = LinearLayout(activity)
        wrap.setOrientation(LinearLayout.VERTICAL)
        wrap.addView(row, LinearLayout.LayoutParams(-1, -2))
        searchResults.addView(wrap)
      end
    end
    if matched == 0 then
      searchResults.addView(ui.empty({
        title = "没有匹配的组件",
        message = "换一个关键词试试，例如「按钮」或「弹窗」。",
        action = {
          title = "清空关键词",
          onClick = function()
            renderSearch("")
          end,
        },
      }))
    end
  end

  local search = ui.searchBar({
    hint = "搜索组件，例如 按钮、弹窗",
    onChange = renderSearch,
  })
  page:add(search, 14)
  page:add(searchResults, 4)
  renderSearch("")

  local range = TextView(activity)
  range.setTextSize(13)
  range.setTextColor(palette().secondary)
  range.setPadding(dp(4), dp(6), dp(4), 0)
  range.setText("输入类型：文本")

  local inputType = ui.segmented({
    items = { "文本", "邮箱", "数字" },
    selected = 1,
    onChange = function(index, item)
      range.setText("输入类型：" .. tostring(item))
      if index == 1 then
        emailField.input.setInputType(0x00000001)
      elseif index == 2 then
        emailField.input.setInputType(0x00000021)
      else
        emailField.input.setInputType(0x00000002)
      end
    end,
  })
  page:add(inputType.view, 14)
  page:add(range, 0)

  local actions = LinearLayout(activity)
  actions.setOrientation(LinearLayout.VERTICAL)
  local save = ui.button({
    text = "保存表单",
    style = "filled",
    onClick = function()
      local name = nickname.input.getText().toString()
      if name == "" then
        ui.alert({
          title = "还差一项",
          message = "昵称不能为空。",
          actions = { { title = "知道了" } },
        })
        return
      end
      showInfo("已保存", "昵称：" .. name
        .. "\n手机号：" .. phone.input.getText().toString()
        .. "\n邮箱：" .. emailField.input.getText().toString()
        .. "\n简介：" .. bio.input.getText().toString())
    end,
  })
  actions.addView(save, LinearLayout.LayoutParams(-1, -2))
  local reset = ui.button({
    text = "重置",
    style = "gray",
    onClick = function()
      nickname.input.setText("")
      phone.input.setText("")
      password.input.setText("")
      email.input.setText("")
      emailField.input.setText("")
      bio.input.setText("")
      nicknameHint.setText("昵称不能为空")
      toast("已重置")
    end,
  })
  local resetParams = LinearLayout.LayoutParams(-1, -2)
  resetParams.topMargin = dp(8)
  actions.addView(reset, resetParams)
  page:add(actions, 14)
  page:add(ui.spacer(8))
end

-- ===== 三、弹窗与状态 =====
local function buildDialogs()
  page:add(heading("弹窗", "alert、actionSheet、空态、加载态和主题"))

  page:add(ui.card({
    title = "alert 弹窗",
    subtitle = "一个、两个、三个按钮的不同排布",
  }, function(box)
    box.addView(addButtonStack({
      { text = "单按钮提示", style = "tinted", onClick = function()
        ui.alert({
          title = "提示",
          message = "只有一个按钮时，底部是一整颗按钮。",
          actions = { { title = "知道了" } },
        })
      end },
      { text = "双按钮确认", style = "tinted", onClick = function()
        ui.alert({
          title = "保存修改",
          message = "两个按钮会并排显示。",
          actions = {
            { title = "取消", style = "cancel" },
            { title = "保存", onClick = function() toast("已保存") end },
          },
        })
      end },
      { text = "三按钮选择", style = "tinted", onClick = function()
        ui.alert({
          title = "选择操作",
          message = "三个及以上按钮会纵向排列。",
          actions = {
            { title = "稍后", style = "cancel" },
            { title = "不再提醒", onClick = function() toast("已关闭提醒") end },
            { title = "查看详情", onClick = function() toast("打开详情") end },
          },
        })
      end },
      { text = "危险确认", style = "destructive", onClick = function()
        ui.alert({
          title = "删除这条记录？",
          message = "删除后无法恢复。",
          actions = {
            { title = "取消", style = "cancel" },
            { title = "删除", style = "destructive", onClick = function() toast("已删除") end },
          },
        })
      end },
    }))
  end), 14)

  page:add(ui.card({
    title = "actionSheet",
    subtitle = "从底部弹出，适合多项操作",
  }, function(box)
    box.addView(addButtonStack({
      { text = "打开操作菜单", style = "filled", onClick = function()
        ui.actionSheet({
          title = "更多操作",
          message = "选择一项继续",
          actions = {
            { title = "复制", onClick = function() toast("已复制") end },
            { title = "分享", onClick = function() toast("已分享") end },
            { title = "删除", style = "destructive", onClick = function() toast("已删除") end },
          },
        })
      end },
      { text = "带说明的操作菜单", style = "gray", onClick = function()
        ui.actionSheet({
          title = "LuaX-UI",
          message = "所有操作都只是示例，不会修改文件。",
          actions = {
            { title = "查看手册", onClick = function() showInfo("手册", "打开编辑器手册 → LuaX-UI 组件库。") end },
            { title = "恢复默认", onClick = function() toast("已恢复") end },
          },
        })
      end },
    }))
  end), 14)

  local modeValue = TextView(activity)
  modeValue.setTextSize(13)
  modeValue.setTextColor(palette().secondary)
  modeValue.setPadding(dp(4), dp(6), dp(4), 0)
  modeValue.setText("主题：" .. (ui.appearance == "auto" and "跟随系统" or ui.appearance))

  local modeSegment = ui.segmented({
    items = { "浅色", "深色", "跟随系统" },
    selected = (ui.appearance == "dark" and 2 or (ui.appearance == "light" and 1 or 3)),
    onChange = function(index)
      if index == 1 then
        ui.setAppearance("light")
      elseif index == 2 then
        ui.setAppearance("dark")
      else
        ui.setAppearance("auto")
      end
      currentTab = 3
      buildShell(3)
    end,
  })
  page:add(modeSegment.view, 14)
  page:add(modeValue, 0)

  local accentRow = LinearLayout(activity)
  accentRow.setOrientation(LinearLayout.HORIZONTAL)
  accentRow.setPadding(dp(4), dp(8), dp(4), 0)
  local ACCENTS = {
    { "蓝", 0xFF007AFF },
    { "绿", 0xFF34C759 },
    { "橙", 0xFFFF9500 },
    { "紫", 0xFFAF52DE },
  }
  for index = 1, #ACCENTS do
    local item = ACCENTS[index]
    local button = ui.button({
      text = item[1],
      style = "tinted",
      textSize = 13,
      onClick = function()
        ui.setAccent(item[2])
        currentTab = 3
        buildShell(3)
      end,
    })
    local params = LinearLayout.LayoutParams(0, dp(40), 1)
    if index > 1 then
      params.leftMargin = dp(6)
    end
    accentRow.addView(button, params)
  end
  page:add(accentRow, 0)

  page:add(ui.empty({
    title = "空状态",
    message = "empty 可以带一个恢复操作。",
    action = {
      title = "点我恢复",
      onClick = function()
        toast("这是 empty 的 action")
      end,
    },
  }), 14)

  page:add(ui.card({
    title = "加载状态",
    subtitle = "loading 适合列表或页面等待",
  }, function(box)
    box.addView(ui.loading({ text = "正在加载组件…" }))
  end), 14)

  page:add(ui.card({
    title = "分割线与间距",
    subtitle = "divider / spacer",
  }, function(box)
    box.addView(ui.divider(0))
    box.addView(ui.spacer(8))
    local row = ui.row({
      title = "间距之后",
      subtitle = "spacer(8) 撑开了这一段",
      value = "8dp",
      chevron = false,
    })
    box.addView(row)
  end), 14)
  page:add(ui.spacer(8))
end

-- ===== 四、关于 =====
local function buildAbout()
  page:add(heading("关于", "LuaX-UI 的边界、组件清单与接入方式"))

  page:add(ui.card(nil, function(box)
    local head = LinearLayout(activity)
    head.setOrientation(LinearLayout.HORIZONTAL)
    head.setGravity(Gravity.CENTER_VERTICAL)

    head.addView(ui.avatar("UI", palette().blue, 58))

    local info = LinearLayout(activity)
    info.setOrientation(LinearLayout.VERTICAL)
    local infoParams = LinearLayout.LayoutParams(0, -2, 1)
    infoParams.leftMargin = dp(14)
    head.addView(info, infoParams)

    local name = TextView(activity)
    name.setText("LuaX-UI")
    name.setTextSize(20)
    name.setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL))
    name.setTextColor(palette().label)
    info.addView(name)

    local sub = TextView(activity)
    sub.setText("纯增量 iOS 风格组件库")
    sub.setTextSize(13)
    sub.setTextColor(palette().secondary)
    sub.setPadding(0, dp(4), 0, 0)
    info.addView(sub)

    local badgeRow = LinearLayout(activity)
    badgeRow.setOrientation(LinearLayout.HORIZONTAL)
    badgeRow.setPadding(0, dp(6), 0, 0)
    local b1 = ui.badge("自研", palette().blue)
    badgeRow.addView(b1)
    local b2 = ui.badge("不改原生", palette().green)
    local b2Params = LinearLayout.LayoutParams(-2, -2)
    b2Params.leftMargin = dp(6)
    badgeRow.addView(b2, b2Params)
    info.addView(badgeRow)

    box.addView(head, LinearLayout.LayoutParams(-1, -2))

    local note = TextView(activity)
    note.setText("所有组件返回普通 Android View，页面仍然可以 addView、setContentView，也可以和原生控件混排。")
    note.setTextSize(13)
    note.setTextColor(palette().secondary)
    note.setPadding(0, dp(14), 0, 0)
    box.addView(note)
  end), 0)

  page:add(ui.group("组件清单", {
    ui.row({ icon = "P", iconBg = palette().blue, title = "页面骨架", subtitle = "page", value = "1", chevron = false }),
    ui.row({ icon = "G", iconBg = palette().green, title = "分组与行", subtitle = "group / row", value = "2", chevron = false }),
    ui.row({ icon = "B", iconBg = palette().orange, title = "按钮", subtitle = "6 种样式", value = "1", chevron = false }),
    ui.row({ icon = "F", iconBg = palette().blue, title = "表单", subtitle = "fieldRow / field / textArea / searchBar", value = "4", chevron = false }),
    ui.row({ icon = "S", iconBg = palette().green, title = "分段控件", subtitle = "segmented", value = "1", chevron = false }),
    ui.row({ icon = "C", iconBg = palette().orange, title = "卡片", subtitle = "card", value = "1", chevron = false }),
    ui.row({ icon = "D", iconBg = palette().red, title = "弹窗", subtitle = "alert / actionSheet", value = "2", chevron = false }),
    ui.row({ icon = "T", iconBg = palette().blue, title = "标签栏", subtitle = "tabBar", value = "1", chevron = false }),
    ui.row({ icon = "M", iconBg = palette().green, title = "状态与装饰", subtitle = "empty / loading / avatar / badge / divider / spacer", value = "6", chevron = false }),
  }, "上面这些就是当前组件库的完整清单。"))

  local code = TextView(activity)
  code.setText('local ui = require "luaxplus.ui"\n\n'
    .. 'local page = ui.page({ title = "设置" })\n\n'
    .. 'page.content.addView(ui.group("通用", {\n'
    .. '  ui.row({ title = "Wi-Fi", value = "Home", chevron = true }),\n'
    .. '  ui.row({ title = "蓝牙", toggle = true, checked = true })\n'
    .. '}))\n\n'
    .. 'page:show()')
  code.setTextSize(12)
  code.setTextColor(palette().label)
  code.setTypeface(Typeface.MONOSPACE)
  code.setBackgroundColor(palette().fill)
  code.setPadding(dp(12), dp(12), dp(12), dp(12))

  page:add(ui.card({
    title = "三行接入",
    subtitle = "不接管 setContentView，也不改写 import",
  }, function(box)
    box.addView(code, LinearLayout.LayoutParams(-1, -2))
  end), 14)

  page:add(ui.group("说明", {
    ui.row({
      icon = "?",
      iconBg = palette().blue,
      title = "查看内置手册",
      subtitle = "编辑器 → 手册 → LuaX-UI 组件库",
      chevron = true,
      onClick = function()
        showInfo("内置手册", "打开编辑器左侧栏的「手册」，首页有 LuaX-UI 组件库卡片，包含字段表和完整用例。")
      end,
    }),
    ui.row({
      icon = "!",
      iconBg = palette().orange,
      title = "与原生写法并存",
      subtitle = "import、luajava、LuaActivity 都没有被改写",
      chevron = true,
      onClick = function()
        showInfo("纯增量", "组件库只是把普通 View 组合起来。你仍然可以直接创建 TextView，或把组件和原生 View 放进同一个布局。")
      end,
    }),
    ui.row({
      icon = "↻",
      iconBg = palette().green,
      title = "主题状态",
      subtitle = "浅色、深色、跟随系统",
      value = ui.appearance == "auto" and "自动" or ui.appearance,
      chevron = false,
    }),
  }, "当前示例工程可以在工程页里直接编辑、运行和打包。"))

  local back = ui.button({
    text = "回到控件页",
    style = "filled",
    onClick = function()
      showTab(1)
    end,
  })
  page:add(back, 14)
  page:add(ui.spacer(8))
end

local BUILDERS = {
  buildControls,
  buildForms,
  buildDialogs,
  buildAbout,
}

showTab = function(index)
  if index < 1 or index > #BUILDERS then
    return
  end
  currentTab = index
  page.content.removeAllViews()
  page:setTitle("LuaX-UI · " .. TAB_TITLES[index])
  BUILDERS[index]()
  page.scroll.scrollTo(0, 0)
  if tabBar then
    tabBar.setSelected(index)
  end
end

buildShell = function(index)
  currentTab = index or currentTab or 1
  page = ui.page({
    title = "LuaX-UI",
    subtitle = "纯增量组件库 · 全量示例",
    largeTitle = false,
    back = true,
    right = {
      title = "说明",
      onClick = function()
        showInfo("LuaX-UI", "这是纯增量组件库示例。页面右侧按钮、返回按钮和标题都由 ui.page 提供。")
      end,
    },
  })

  tabBar = ui.tabBar({
    selected = currentTab,
    items = {
      { icon = "◻", title = "控件" },
      { icon = "✎", title = "表单" },
      { icon = "◉", title = "弹窗" },
      { icon = "ⓘ", title = "关于" },
    },
    onChange = function(index)
      showTab(index)
    end,
  })

  page:show()
  page.root.addView(tabBar.view, LinearLayout.LayoutParams(-1, -2))
  showTab(currentTab)
end

buildShell(1)
