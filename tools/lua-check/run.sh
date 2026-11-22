#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

LUA_BIN="${LUA_BIN:-}"
if [ -z "$LUA_BIN" ]; then
  if command -v lua5.3 >/dev/null 2>&1; then
    LUA_BIN="lua5.3"
  elif command -v lua >/dev/null 2>&1; then
    LUA_BIN="lua"
  else
    echo "[lua-check] 找不到 Lua 解释器，请安装 lua5.3 或设置 LUA_BIN" >&2
    exit 1
  fi
fi

echo "[lua-check] Lua: $($LUA_BIN -v 2>&1 | head -1)"
"$LUA_BIN" tools/lua-check/check_syntax.lua
"$LUA_BIN" tools/lua-smoke/run.lua
"$LUA_BIN" tools/lua-smoke/packcheck_test.lua
"$LUA_BIN" tools/lua-smoke/pkgname_test.lua
"$LUA_BIN" tools/lua-smoke/icons_test.lua
"$LUA_BIN" tools/lua-smoke/lint_test.lua
echo "[lua-check] 全部通过"
