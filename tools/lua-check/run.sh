#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

LUA_BIN="${LUA_BIN:-}"
if [ -z "$LUA_BIN" ]; then
  for candidate in lua5.5 lua5.4 lua5.3 lua; do
    if command -v "$candidate" >/dev/null 2>&1; then
      LUA_BIN="$candidate"
      break
    fi
  done
  if [ -z "$LUA_BIN" ]; then
    echo "[lua-check] 找不到 Lua 解释器，请安装 Lua 5.5 或设置 LUA_BIN" >&2
    exit 1
  fi
fi

# 5.5 运行时需要兼容层承接 loadstring、module、bit32 等旧接口。
if [ -z "${LUA_INIT:-}" ] && [ -f "$ROOT_DIR/app/src/main/resources/lua/lua55_compat.lua" ]; then
  export LUA_INIT="@$ROOT_DIR/app/src/main/resources/lua/lua55_compat.lua"
fi

echo "[lua-check] Lua: $($LUA_BIN -v 2>&1 | head -1)"
"$LUA_BIN" tools/lua-check/check_syntax.lua
"$LUA_BIN" tools/lua-smoke/run.lua
"$LUA_BIN" tools/lua-smoke/packcheck_test.lua
"$LUA_BIN" tools/lua-smoke/pkgname_test.lua
"$LUA_BIN" tools/lua-smoke/icons_test.lua
"$LUA_BIN" tools/lua-smoke/lint_test.lua
echo "[lua-check] 全部通过"
