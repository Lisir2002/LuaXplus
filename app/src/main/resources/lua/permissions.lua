-- 权限助手：一行调用即可按需申请，脚本不必各自编写授权流程
-- 用法：import "permissions"; permissions.ensure("storage", "camera", "microphone")

local Permissions = luajava.bindClass("com.mini.luaxplus.Permissions")
local M = {}

local mapping = {
  storage = "android.permission.MANAGE_EXTERNAL_STORAGE",
  read_storage = "android.permission.READ_EXTERNAL_STORAGE",
  write_storage = "android.permission.WRITE_EXTERNAL_STORAGE",
  camera = "android.permission.CAMERA",
  microphone = "android.permission.RECORD_AUDIO",
  contacts = "android.permission.READ_CONTACTS",
  calendar = "android.permission.READ_CALENDAR",
  location = "android.permission.ACCESS_FINE_LOCATION",
  phone = "android.permission.CALL_PHONE",
  sms = "android.permission.READ_SMS",
  notification = "android.permission.POST_NOTIFICATIONS",
  overlay = "android.permission.SYSTEM_ALERT_WINDOW",
}

function M.ensure(...)
  local need = {}
  for _, name in ipairs({...}) do
    local permission = mapping[name] or name
    if name == "storage" or name == "allfiles" then
      if not Permissions.allFiles() then
        Permissions.requestAllFiles(activity)
      end
    elseif not Permissions.granted(activity, permission) then
      table.insert(need, permission)
    end
  end
  if #need > 0 then
    Permissions.request(activity, table.concat(need, ","))
  end
  return true
end

function M.granted(name)
  local permission = mapping[name] or name
  if name == "storage" or name == "allfiles" then
    return Permissions.allFiles()
  end
  return Permissions.granted(activity, permission)
end

return M
