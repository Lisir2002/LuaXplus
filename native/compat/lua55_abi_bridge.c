#include <stddef.h>

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

/* Lua 5.5 把头文件里的旧接口改成了宏，这里显式导出同名符号，
   让尚未重编的预编译模块仍能按原符号加载。 */
#undef lua_newuserdata
#undef lua_getuservalue
#undef lua_setuservalue
#undef lua_objlen
#undef luaL_register
#undef luaL_openlibs
#undef lua_pushunsigned
#undef lua_tounsignedx

void *lua_newuserdata(lua_State *L, size_t size) {
  return lua_newuserdatauv(L, size, 1);
}

int lua_getuservalue(lua_State *L, int idx) {
  return lua_getiuservalue(L, idx, 1);
}

int lua_setuservalue(lua_State *L, int idx) {
  lua_setiuservalue(L, idx, 1);
  return 1;
}

size_t lua_objlen(lua_State *L, int idx) {
  return lua_rawlen(L, idx);
}

void lua_pushunsigned(lua_State *L, lua_Unsigned n) {
  lua_pushinteger(L, (lua_Integer)n);
}

lua_Unsigned lua_tounsignedx(lua_State *L, int idx, int *isnum) {
  return (lua_Unsigned)lua_tointegerx(L, idx, isnum);
}

void luaL_openlib(lua_State *L, const char *libname, const luaL_Reg *l,
                  int nup) {
  if (libname) {
    lua_createtable(L, 0, 0);
    luaL_setfuncs(L, l, nup);
    lua_setglobal(L, libname);
    lua_getglobal(L, libname);
  } else {
    luaL_setfuncs(L, l, nup);
  }
}

void luaL_register(lua_State *L, const char *libname, const luaL_Reg *l) {
  luaL_openlib(L, libname, l, 0);
}

void luaL_openlibs(lua_State *L) {
  luaL_openselectedlibs(L, ~0, 0);
}

int luaL_typerror(lua_State *L, int narg, const char *tname) {
  const char *msg = lua_pushfstring(L, "%s expected, got %s", tname,
                                    luaL_typename(L, narg));
  return luaL_argerror(L, narg, msg);
}
