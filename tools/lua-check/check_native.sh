#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

EXPECTED="Lua 5.5.1"
FAIL=0

fail() {
  echo "[native-check] $*" >&2
  FAIL=1
}

version_of() {
  local so="$1"
  if command -v strings >/dev/null 2>&1; then
    strings "$so" 2>/dev/null | grep -o 'Lua 5\.[0-9][0-9.]*' | head -1 || true
  else
    grep -a -o 'Lua 5\.[0-9][0-9.]*' "$so" 2>/dev/null | head -1 || true
  fi
}

# 两套 ABI 目录都必须完整保留，避免只替换一半架构。
for root in androlua/src/main/jniLibs app/src/main/jniLibs; do
  count="$(find "$root" -type f -name 'libluajava.so' 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$count" -ne 4 ]; then
    fail "目录 $root 下 libluajava.so 数量为 $count，期望 4 个 ABI"
  fi
done

while IFS= read -r so; do
  version="$(version_of "$so")"
  if [ "$version" != "$EXPECTED" ]; then
    fail "$so 的版本为 '${version:-未知}'，期望 '$EXPECTED'；不要换回旧 Lua 5.3 库"
  fi
done < <(find androlua/src/main/jniLibs app/src/main/jniLibs -type f -name 'libluajava.so' 2>/dev/null)

# JAR 里不能再带旧 com.luajava 字节码，否则会绕过源码桥接并与 5.5 原生库错配。
JAR="androlua/libs/AndroLua+5.0.18_AndroidX.jar"
if [ ! -f "$JAR" ]; then
  fail "缺少 $JAR"
elif unzip -l "$JAR" 2>/dev/null | grep -q 'com/luajava/'; then
  fail "$JAR 仍包含旧 com/luajava 字节码，请使用当前源码桥接版本"
fi

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi

echo "[native-check] libluajava.so 全部为 $EXPECTED，JAR 无旧 luajava 字节码"
