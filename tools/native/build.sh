#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEFAULT_NDK="/home/user/Android/Sdk/ndk/27.0.12077973"
if [ -n "${ANDROID_NDK_HOME:-}" ]; then
  NDK="${ANDROID_NDK_HOME}"
elif [ -x "${DEFAULT_NDK}/ndk-build" ]; then
  NDK="${DEFAULT_NDK}"
else
  NDK="${ANDROID_HOME:-/home/user/Android/Sdk}/ndk/27.0.12077973"
fi
BUILD_ROOT="${ROOT_DIR}/build/native"
if [ "$#" -eq 0 ]; then
  ABIS=(arm64-v8a)
else
  ABIS=("$@")
  if [ "${#ABIS[@]}" -eq 1 ] && [[ "${ABIS[0]}" == *" "* ]]; then
    read -r -a ABIS <<< "${ABIS[0]}"
  fi
fi

if [ ! -x "${NDK}/ndk-build" ]; then
  echo "[native] NDK 不可用: ${NDK}" >&2
  exit 1
fi

STRIP="${NDK}/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip"
for ABI in "${ABIS[@]}"; do
  echo "[native] 配置 ${ABI}"
  cmake -S "${ROOT_DIR}/native" -B "${BUILD_ROOT}/${ABI}" \
    -DCMAKE_TOOLCHAIN_FILE="${NDK}/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI="${ABI}" \
    -DANDROID_PLATFORM=android-21 \
    -DCMAKE_BUILD_TYPE=Release \
    -G Ninja >/dev/null
  echo "[native] 编译 ${ABI}"
  cmake --build "${BUILD_ROOT}/${ABI}" -j 4
  find "${BUILD_ROOT}/${ABI}" -maxdepth 1 -name 'lib*.so' -print0 | while IFS= read -r -d '' so; do
    "${STRIP}" --strip-unneeded "$so"
  done
done

echo "[native] 产物目录: ${BUILD_ROOT}/<abi>"
