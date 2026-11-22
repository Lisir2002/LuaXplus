#ifndef MINI_LUAX_LUA55_COMPAT_H
#define MINI_LUAX_LUA55_COMPAT_H

#ifdef __cplusplus
extern "C" {
#endif

#include "lua.h"
#include "lauxlib.h"

/* 旧模块使用 5.1 的小写类型名，5.5 只剩 luaL_Reg */
#define luaL_reg luaL_Reg

/* 5.5 已移除 luaL_openlib，保留一个最小等价实现供旧模块编译 */
static void luaL_openlib(lua_State *L, const char *libname,
                         const luaL_Reg *l, int nup) {
  if (libname) {
    int base = lua_gettop(L) - nup + 1;
    lua_createtable(L, 0, 0);
    for (int i = 0; i < nup; i++) {
      lua_pushvalue(L, base + i);
    }
    luaL_setfuncs(L, l, nup);
    lua_setglobal(L, libname);
    lua_getglobal(L, libname);
  } else {
    luaL_setfuncs(L, l, nup);
  }
}

#define luaL_register(L, n, l) luaL_openlib((L), (n), (l), 0)


#ifndef luaL_checkint
#define luaL_checkint(L, n) ((int)luaL_checkinteger((L), (n)))
#endif
#ifndef luaL_optint
#define luaL_optint(L, n, d) ((int)luaL_optinteger((L), (n), (d)))
#endif
#ifndef luaL_checklong
#define luaL_checklong(L, n) ((long)luaL_checkinteger((L), (n)))
#endif
#ifndef luaL_optlong
#define luaL_optlong(L, n, d) ((long)luaL_optinteger((L), (n), (d)))
#endif

/* 5.1 的 unsigned 接口在 5.5 没有对应函数，统一走 integer */
#ifndef lua_pushunsigned
#define lua_pushunsigned(L, n) lua_pushinteger((L), (lua_Integer)(n))
#endif
#ifndef lua_tounsignedx
#define lua_tounsignedx(L, i, isn) \
  ((lua_Unsigned)lua_tointegerx((L), (i), (isn)))
#endif
#ifndef luaL_checkunsigned
#define luaL_checkunsigned(L, n) \
  ((lua_Unsigned)luaL_checkinteger((L), (n)))
#endif
#ifndef luaL_optunsigned
#define luaL_optunsigned(L, n, d) \
  ((lua_Unsigned)luaL_optinteger((L), (n), (d)))
#endif

#ifdef __cplusplus
}
#endif

#endif
