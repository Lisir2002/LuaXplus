require "import"
import "android.widget.*"
import "android.view.*"
import "android.webkit.*"
import "com.androlua.*"
import "android.app.*"
import "autotheme"
local theme = require "luaxplus.theme"

-- 手册页面放在安装包内置资源里，用 android_asset 地址读取，
-- 避免直接访问应用私有目录被浏览器内核拒绝
local HOME = "file:///android_asset/luadoc/contents.html"

activity.setTheme(autotheme())
activity.setTitle("使用手册")
activity.getSupportActionBar().setDisplayHomeAsUpEnabled(true)

items = {"目录"}
function onCreateOptionsMenu(menu)
  for k, v in ipairs(items) do
    local m = menu.add(v)
    m.setShowAsActionFlags(1)
  end
end

function onOptionsItemSelected(item)
  local id = item.getItemId()
  if id == android.R.id.home then
    activity.finish()
  else
    onMenuItemSelected(id, item)
  end
end

function onMenuItemSelected(id, item)
  func[item.getTitle()]()
end

func = {}
func["目录"] = function()
  doc_web.loadUrl(HOME)
end

doc_web = LuaWebView(activity)
local settings = doc_web.getSettings()
settings.setJavaScriptEnabled(true)
settings.setAllowFileAccess(true)
settings.setAllowFileAccessFromFileURLs(true)
settings.setAllowUniversalAccessFromFileURLs(true)
settings.setBuiltInZoomControls(false)
settings.setDisplayZoomControls(false)
settings.setTextZoom(100)

doc_web.setBackgroundColor(theme.colors.paper)
doc_web.loadUrl(HOME)

doc_web.setOnKeyListener(View.OnKeyListener{
  onKey = function(view, keyCode, event)
    if keyCode == event.KEYCODE_BACK and view.canGoBack() then
      view.goBack()
      return true
    end
    return false
  end
})

theme.apply(activity, { background = theme.colors.paper, dark = false })
activity.setContentView(doc_web)
