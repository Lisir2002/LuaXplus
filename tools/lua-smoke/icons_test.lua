-- 图标着色回归：VectorDrawable 只接受 ColorFilter 对象，不能传颜色整数。
-- 这个测试把 Android 侧最小契约固定下来，防止再次出现 LuaJava Invalid method call。

package.preload["import"] = function()
  return {}
end
function import() end

local function fail(message)
  error("[icons-test] " .. message, 2)
end

local function expect(condition, message)
  if not condition then
    fail(message)
  end
end

TextView = function() return {} end
ImageView = function() return {} end
FrameLayout = { LayoutParams = function() return {} end }
GradientDrawable = function() return {} end
Typeface = { DEFAULT_BOLD = 1 }
Gravity = { CENTER = 1 }
View = {}
LinearLayout = { LayoutParams = function() return {} end }
FrameLayout.LayoutParams = function() return {} end

PorterDuff = { Mode = { SRC_IN = 1 } }
PorterDuffColorFilter = function(color, mode)
  return { color = color, mode = mode }
end

activity = {
  getResources = function()
    return { getDisplayMetrics = function() return { density = 2 } end }
  end,
  getPackageName = function() return "com.mini.luaxplus" end,
}

package.path = "./app/src/main/assets/lua/?.lua;" .. package.path
local icons = require "luaxplus.icons"
expect(type(icons.tintDrawable) == "function", "tintDrawable 没有导出")

local received
local drawable = {
  setColorFilter = function(filter)
    expect(type(filter) == "table", "Drawable 必须收到 ColorFilter 对象")
    received = filter
  end,
}
icons.tintDrawable(drawable, 0xFF1C2B3A)
expect(received and received.color == 0xFF1C2B3A, "着色颜色没有传到 Drawable")
expect(received.mode == PorterDuff.Mode.SRC_IN, "着色模式不是 SRC_IN")

-- 没有资源时必须安全返回，不能因为缺 Drawable 报错。
expect(icons.tintDrawable(nil, 0xFF000000) == nil, "空 Drawable 没有安全返回")

print("[icons-test] 图标着色回归通过")
