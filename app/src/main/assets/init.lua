appname="Mini-LuaXPLUS"
appver="1.0"
app_key="4yCilmN24RCRG82uc93kSZ1F"
app_channel="qq group"
packagename="com.mini.luaxplus"
user_permission={
  "INTERNET",
  "WRITE_EXTERNAL_STORAGE",
}

-- 由应用自行管理权限申请，避免启动时批量申请清单内全部权限
function check_permissions()
  return true
end
