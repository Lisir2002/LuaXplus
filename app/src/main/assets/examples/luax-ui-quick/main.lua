require "import"
import "android.widget.*"
import "android.view.*"

local ui = require "luaxplus.ui"

local form = ui.form({
  title = "账号",
  fields = {
    { name = "nickname", label = "昵称", placeholder = "输入昵称", value = "LuaX" },
    { name = "email", label = "邮箱", placeholder = "name@example.com", email = true },
    { name = "password", label = "密码", placeholder = "输入密码", secure = true },
  },
  footer = "ui.form 会自动生成一组 fieldRow，并返回 getValues()。",
})

local save = ui.button({
  text = "保存",
  style = "filled",
  onClick = function()
    local values = form.getValues()
    ui.alert({
      title = "已保存",
      message = "昵称：" .. values.nickname .. "\n邮箱：" .. values.email,
      actions = { { title = "好" } },
    })
  end,
})

ui.show({
  title = "快速上手",
  subtitle = "一个页面、一个表单、一个按钮",
  back = true,
  content = function(_, page)
    page:add(form.view)
    page:add(save, 12)
    page:add(ui.button({
      text = "重置表单",
      style = "gray",
      onClick = function()
        form.reset()
        ui.toast("已重置")
      end,
    }), 8)
  end,
})
