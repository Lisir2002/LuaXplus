require "import"
import "android.app.*"
import "android.os.*"
import "android.widget.*"
import "android.view.*"
import "android.content.*"
import "android.net.Uri"
import "android.provider.Settings"
import "autotheme"

activity.setTheme(autotheme())
local ui = require "luaxplus.ui"
local P = luajava.bindClass("com.mini.luaxplus.Permissions")
local Build = luajava.bindClass("android.os.Build")
local Toast = luajava.bindClass("android.widget.Toast")

local sdk = Build.VERSION.SDK_INT
local packageName = activity.getPackageName()
local pm = activity.getPackageManager()

local function toast(text)
  Toast.makeText(activity, tostring(text), Toast.LENGTH_SHORT).show()
end

-- 常见权限的中文名称；未覆盖的权限回退到系统权限名，保证“全量”可见。
local LABELS = {
  ["android.permission.INTERNET"] = "网络访问",
  ["android.permission.ACCESS_NETWORK_STATE"] = "网络状态",
  ["android.permission.ACCESS_WIFI_STATE"] = "无线网络状态",
  ["android.permission.CHANGE_WIFI_STATE"] = "修改无线网络",
  ["android.permission.CHANGE_WIFI_MULTICAST_STATE"] = "无线多播",
  ["android.permission.CHANGE_NETWORK_STATE"] = "修改网络状态",
  ["android.permission.READ_EXTERNAL_STORAGE"] = "读取存储",
  ["android.permission.WRITE_EXTERNAL_STORAGE"] = "写入存储",
  ["android.permission.MANAGE_EXTERNAL_STORAGE"] = "所有文件访问",
  ["android.permission.POST_NOTIFICATIONS"] = "通知",
  ["android.permission.READ_MEDIA_IMAGES"] = "读取图片",
  ["android.permission.READ_MEDIA_VIDEO"] = "读取视频",
  ["android.permission.READ_MEDIA_AUDIO"] = "读取音频",
  ["android.permission.READ_MEDIA_VISUAL_USER_SELECTED"] = "选择部分图片/视频",
  ["android.permission.CAMERA"] = "相机",
  ["android.permission.RECORD_AUDIO"] = "录音",
  ["android.permission.ACCESS_FINE_LOCATION"] = "精确位置",
  ["android.permission.ACCESS_COARSE_LOCATION"] = "大致位置",
  ["android.permission.ACCESS_BACKGROUND_LOCATION"] = "后台位置",
  ["android.permission.ACCESS_MEDIA_LOCATION"] = "媒体位置信息",
  ["android.permission.READ_CONTACTS"] = "读取联系人",
  ["android.permission.WRITE_CONTACTS"] = "修改联系人",
  ["android.permission.READ_CALENDAR"] = "读取日历",
  ["android.permission.WRITE_CALENDAR"] = "修改日历",
  ["android.permission.READ_CALL_LOG"] = "读取通话记录",
  ["android.permission.WRITE_CALL_LOG"] = "修改通话记录",
  ["android.permission.READ_PHONE_STATE"] = "读取电话状态",
  ["android.permission.READ_PHONE_NUMBERS"] = "读取电话号码",
  ["android.permission.CALL_PHONE"] = "拨打电话",
  ["android.permission.ANSWER_PHONE_CALLS"] = "接听电话",
  ["android.permission.READ_SMS"] = "读取短信",
  ["android.permission.RECEIVE_SMS"] = "接收短信",
  ["android.permission.RECEIVE_MMS"] = "接收彩信",
  ["android.permission.SEND_SMS"] = "发送短信",
  ["android.permission.BODY_SENSORS"] = "身体传感器",
  ["android.permission.ACTIVITY_RECOGNITION"] = "运动识别",
  ["android.permission.BLUETOOTH_SCAN"] = "扫描蓝牙设备",
  ["android.permission.BLUETOOTH_CONNECT"] = "连接蓝牙设备",
  ["android.permission.BLUETOOTH_ADVERTISE"] = "蓝牙广播",
  ["android.permission.NEARBY_WIFI_DEVICES"] = "附近 Wi-Fi 设备",
  ["android.permission.WRITE_SETTINGS"] = "修改系统设置",
  ["android.permission.REQUEST_INSTALL_PACKAGES"] = "安装未知应用",
  ["android.permission.ACCESS_NOTIFICATION_POLICY"] = "勿扰模式访问",
  ["android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"] = "忽略电池优化",
  ["android.permission.INSTALL_PACKAGES"] = "安装应用（系统签名）",
  ["android.permission.START_VIEW_PERMISSION_USAGE"] = "查看权限用途",
  ["android.permission.BIND_ACCESSIBILITY_SERVICE"] = "无障碍服务",
  ["com.android.launcher.permission.INSTALL_SHORTCUT"] = "安装快捷方式",
  ["com.android.launcher.permission.UNINSTALL_SHORTCUT"] = "卸载快捷方式",
}

local SPECIAL = {
  ["android.permission.MANAGE_EXTERNAL_STORAGE"] = {
    label = "所有文件访问",
    desc = "工程、备份和导出文件保存在设备存储中",
    category = "存储与网络",
    minSdk = 30,
    check = function() return P.allFiles() end,
    open = function() P.openAllFilesSettings(activity) end,
  },
  ["android.permission.WRITE_SETTINGS"] = {
    label = "修改系统设置",
    desc = "修改亮度、音量等系统设置时需要",
    category = "特殊访问",
    minSdk = 23,
    check = function() return P.writeSettingsGranted(activity) end,
    open = function() P.openWriteSettings(activity) end,
  },
  ["android.permission.REQUEST_INSTALL_PACKAGES"] = {
    label = "安装未知应用",
    desc = "安装导出的 APK 或调试包时需要",
    category = "特殊访问",
    minSdk = 26,
    check = function() return P.installPackagesGranted(activity) end,
    open = function() P.openInstallSettings(activity) end,
  },
  ["android.permission.ACCESS_NOTIFICATION_POLICY"] = {
    label = "勿扰模式访问",
    desc = "读取或切换勿扰模式时需要",
    category = "通知与媒体",
    minSdk = 23,
    check = function() return P.notificationPolicyGranted(activity) end,
    open = function() P.openNotificationPolicySettings(activity) end,
  },
  ["android.permission.BIND_ACCESSIBILITY_SERVICE"] = {
    label = "无障碍服务",
    desc = "自动化操作和界面辅助需要手动开启",
    category = "特殊访问",
    minSdk = 16,
    check = function() return P.accessibilityEnabled(activity) end,
    open = function() P.openAccessibilitySettings(activity) end,
  },
}

local function applies(permission)
  if permission == "android.permission.POST_NOTIFICATIONS" then
    return sdk >= 33
  elseif permission == "android.permission.READ_MEDIA_IMAGES"
      or permission == "android.permission.READ_MEDIA_VIDEO"
      or permission == "android.permission.READ_MEDIA_AUDIO" then
    return sdk >= 33
  elseif permission == "android.permission.READ_MEDIA_VISUAL_USER_SELECTED" then
    return sdk >= 34
  elseif permission == "android.permission.BLUETOOTH_SCAN"
      or permission == "android.permission.BLUETOOTH_CONNECT"
      or permission == "android.permission.BLUETOOTH_ADVERTISE" then
    return sdk >= 31
  elseif permission == "android.permission.NEARBY_WIFI_DEVICES" then
    return sdk >= 33
  elseif permission == "android.permission.ACCESS_BACKGROUND_LOCATION"
      or permission == "android.permission.ACTIVITY_RECOGNITION"
      or permission == "android.permission.ACCESS_MEDIA_LOCATION" then
    return sdk >= 29
  elseif permission == "android.permission.READ_PHONE_NUMBERS"
      or permission == "android.permission.ANSWER_PHONE_CALLS"
      or permission == "android.permission.REQUEST_INSTALL_PACKAGES" then
    return sdk >= 26
  elseif permission == "android.permission.READ_EXTERNAL_STORAGE"
      or permission == "android.permission.WRITE_EXTERNAL_STORAGE" then
    return sdk <= 32
  end
  local special = SPECIAL[permission]
  if special and special.minSdk then
    return sdk >= special.minSdk
  end
  return true
end

local function labelOf(permission)
  local special = SPECIAL[permission]
  if special and special.label then
    return special.label
  end
  if LABELS[permission] then
    return LABELS[permission]
  end
  return (permission:match("([^%.]+)$") or permission):gsub("_", " ")
end

local function kindOf(permission)
  if SPECIAL[permission] then
    return "special"
  end
  local ok, info = pcall(function()
    return pm.getPermissionInfo(permission, 0)
  end)
  if ok and info then
    local base = info.protectionLevel % 16
    if base == 1 then
      return "runtime"
    elseif base == 2 or base == 3 then
      return "signature"
    end
  end
  return "normal"
end

local function categoryOf(permission, kind)
  local special = SPECIAL[permission]
  if special and special.category then
    return special.category
  end
  if permission == "android.permission.INTERNET"
      or permission == "android.permission.ACCESS_NETWORK_STATE"
      or permission == "android.permission.ACCESS_WIFI_STATE"
      or permission == "android.permission.CHANGE_WIFI_STATE"
      or permission == "android.permission.CHANGE_WIFI_MULTICAST_STATE"
      or permission == "android.permission.CHANGE_NETWORK_STATE"
      or permission:find("EXTERNAL_STORAGE", 1, true) then
    return "存储与网络"
  end
  if permission == "android.permission.POST_NOTIFICATIONS"
      or permission:find("READ_MEDIA", 1, true) then
    return "通知与媒体"
  end
  if permission == "android.permission.CAMERA"
      or permission == "android.permission.RECORD_AUDIO"
      or permission:find("LOCATION", 1, true) then
    return "相机、麦克风与位置"
  end
  if permission:find("CONTACT", 1, true)
      or permission:find("CALENDAR", 1, true)
      or permission:find("CALL", 1, true)
      or permission:find("PHONE", 1, true) then
    return "联系人与通话"
  end
  if permission:find("SMS", 1, true) or permission:find("MMS", 1, true) then
    return "短信"
  end
  if permission:find("SENSOR", 1, true)
      or permission:find("ACTIVITY_RECOGNITION", 1, true) then
    return "传感器"
  end
  if permission:find("BLUETOOTH", 1, true)
      or permission:find("NEARBY_WIFI", 1, true) then
    return "附近设备"
  end
  if kind == "signature" then
    return "系统权限"
  end
  return "其他权限"
end

local requested = {}
local seen = {}
local ok, packageInfo = pcall(function()
  return pm.getPackageInfo(packageName, 4096)
end)
if ok and packageInfo and packageInfo.requestedPermissions then
  for _, permission in ipairs(luajava.astable(packageInfo.requestedPermissions)) do
    if not seen[permission] then
      seen[permission] = true
      requested[#requested + 1] = permission
    end
  end
end
-- 无障碍服务不是 uses-permission，但属于应用能力，单独加入全量管理。
if not seen["android.permission.BIND_ACCESSIBILITY_SERVICE"] then
  requested[#requested + 1] = "android.permission.BIND_ACCESSIBILITY_SERVICE"
end

local entries = {}
for _, permission in ipairs(requested) do
  local special = SPECIAL[permission]
  local kind = kindOf(permission)
  entries[#entries + 1] = {
    permission = permission,
    kind = kind,
    label = labelOf(permission),
    desc = special and special.desc or nil,
    category = categoryOf(permission, kind),
    check = special and special.check or nil,
    open = special and special.open or nil,
  }
end

local function entryApplicable(entry)
  return applies(entry.permission)
end

local function entryGranted(entry)
  if not entryApplicable(entry) then
    return false
  end
  if entry.kind == "normal" or entry.kind == "signature" then
    -- 普通权限安装后自动授予，签名权限只有系统签名或特权应用才真正拥有；
    -- 统一向系统查询实际状态，避免把“声明了但没拿到”的签名权限显示成已授予。
    return P.granted(activity, entry.permission)
  elseif entry.kind == "runtime" then
    return P.granted(activity, entry.permission)
  elseif entry.kind == "special" and entry.check then
    return entry.check() == true
  end
  return false
end

local function statusText(entry)
  if not entryApplicable(entry) then
    return "系统不适用"
  end
  if entry.kind == "normal" then
    return entryGranted(entry) and "自动授予" or "未获得"
  elseif entry.kind == "signature" then
    return entryGranted(entry) and "系统授予" or "未获得"
  elseif entry.kind == "special" then
    return entryGranted(entry) and "已开启" or "未开启"
  end
  return entryGranted(entry) and "已允许" or "未允许"
end

local function rowFor(entry)
  local allowed = entryGranted(entry)
  local applicable = entryApplicable(entry)
  local subtitle
  if not applicable then
    subtitle = "当前系统版本不需要或不可用"
  elseif entry.kind == "normal" then
    subtitle = entryGranted(entry) and "安装时由系统授予，无需手动申请" or "当前系统未授予，普通权限通常随安装自动授予"
  elseif entry.kind == "signature" then
    subtitle = entryGranted(entry) and "系统签名权限，已由系统授予" or "系统签名权限，普通应用无法申请"
  elseif entry.kind == "special" then
    subtitle = (entry.desc or "系统特殊访问") .. " · 点按进入对应设置页"
  elseif allowed then
    subtitle = "已允许 · 点按进入系统设置关闭"
  else
    subtitle = "未允许 · 点按申请；其他权限不会在启动时自动弹窗"
  end
  local onClick
  if applicable and entry.kind == "runtime" then
    onClick = function()
      if P.granted(activity, entry.permission) then
        P.openAppSettings(activity)
      else
        P.request(activity, entry.permission)
      end
    end
  elseif applicable and entry.kind == "special" then
    onClick = function()
      if entry.open then
        entry.open()
      else
        P.openAppSettings(activity)
      end
    end
  end
  return {
    title = entry.label,
    subtitle = subtitle,
    value = statusText(entry),
    onClick = onClick,
    chevron = onClick ~= nil,
  }
end

local function requestRuntimePermissions()
  local missing = {}
  for _, entry in ipairs(entries) do
    if entry.kind == "runtime" and entryApplicable(entry) and not P.granted(activity, entry.permission) then
      missing[#missing + 1] = entry.permission
    end
  end
  if #missing == 0 then
    toast("运行时权限已全部允许")
    return
  end
  P.request(activity, table.concat(missing, ","))
  toast("已提交运行时权限申请；特殊权限请逐项进入系统页开启")
end

local page = ui.page({
  title = "权限管理",
  subtitle = "首次启动只申请存储，其余按需开启",
  back = true,
})

local function render()
  page.content.removeAllViews()

  local total = 0
  local allowed = 0
  for _, entry in ipairs(entries) do
    if entryApplicable(entry) then
      total = total + 1
      if entryGranted(entry) then
        allowed = allowed + 1
      end
    end
  end

  page:add(ui.text({
    text = string.format("已授权 %d / %d 项。网络是普通权限，安装时由系统授予；首次启动只主动申请存储。", allowed, total),
    type = "footnote",
    color = ui.tokens.color.secondary,
  }), 4)

  page:add(ui.hstack({ gap = "8px", fill = true }, function(add)
    add(ui.button({
      text = "一键申请",
      style = "filled",
      onClick = requestRuntimePermissions,
    }))
    add(ui.button({
      text = "一键关闭",
      style = "gray",
      onClick = function()
        P.openAppSettings(activity)
        toast("系统不允许应用直接撤销权限，请在应用权限页关闭")
      end,
    }))
  end))

  page:add(ui.text({
    text = "“一键申请”会批量提交运行时权限；“一键关闭”会打开系统应用权限页。特殊权限无法由应用直接撤销，需在对应系统页操作。",
    type = "footnote",
    color = ui.tokens.color.tertiary,
  }), 8)

  local sections = {}
  for _, entry in ipairs(entries) do
    sections[entry.category] = sections[entry.category] or {}
    sections[entry.category][#sections[entry.category] + 1] = entry
  end

  local order = {
    "存储与网络",
    "通知与媒体",
    "相机、麦克风与位置",
    "联系人与通话",
    "短信",
    "传感器",
    "附近设备",
    "特殊访问",
    "其他权限",
    "系统权限",
  }
  for _, name in ipairs(order) do
    local groupEntries = sections[name]
    if groupEntries and #groupEntries > 0 then
      local rows = {}
      for _, entry in ipairs(groupEntries) do
        rows[#rows + 1] = rowFor(entry)
      end
      page:add(ui.group(name, rows, nil), 10)
    end
  end

  page:add(ui.text({
    text = "权限说明：应用不会在每次启动重复检查权限；如某项功能失效，回到本页点按对应权限即可申请或跳转系统设置。",
    type = "footnote",
    color = ui.tokens.color.secondary,
  }), 14)
end

render()
page:show()
local ready = true

function onResume()
  if ready then
    render()
  end
end

function onRequestPermissionsResult(requestCode, permissions, grantResults)
  render()
end
