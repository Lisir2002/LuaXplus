cmake_minimum_required(VERSION 3.18)
project(mini_luax_native C CXX)

set(CMAKE_C_STANDARD 99)
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

set(ROOT "${CMAKE_CURRENT_SOURCE_DIR}")
set(LUA_INC "${ROOT}/lua")
set(COMPAT "${ROOT}/compat")

file(GLOB LUA_SRC "${LUA_INC}/l*.c")

add_library(luajava SHARED ${LUA_SRC}
  "${ROOT}/luajava/luajava.c"
  "${COMPAT}/lua55_abi_bridge.c")
target_include_directories(luajava PUBLIC "${LUA_INC}")
target_include_directories(luajava PRIVATE "${ROOT}/luajava" "${COMPAT}")
target_compile_definitions(luajava PRIVATE LUA_USE_POSIX LUA_USE_DLOPEN LUA_COMPAT_GLOBAL=1)
target_compile_options(luajava PRIVATE -fvisibility=default -include "${COMPAT}/lua55_android.h")
target_link_libraries(luajava log dl m)

function(add_lua_module name)
  add_library(${name} SHARED ${ARGN})
  target_include_directories(${name} PRIVATE "${LUA_INC}" "${COMPAT}" "${ROOT}/modules/${name}")
  target_compile_definitions(${name} PRIVATE LUA_COMPAT_APIINTCASTS)
  target_compile_options(${name} PRIVATE -include "${COMPAT}/lua55_compat.h")
  target_link_libraries(${name} luajava log dl m)
endfunction()

add_lua_module(bson "${ROOT}/modules/bson/lua-bson.c")
add_lua_module(canvas "${ROOT}/modules/canvas/canvas.c")
add_lua_module(cjson
  "${ROOT}/modules/cjson/lua_cjson.c"
  "${ROOT}/modules/cjson/fpconv.c"
  "${ROOT}/modules/cjson/strbuf.c")
add_lua_module(crypt
  "${ROOT}/modules/crypt/lcrypt.c"
  "${ROOT}/modules/crypt/lsha1.c")
add_lua_module(md5
  "${ROOT}/modules/md5/md5lib.c"
  "${ROOT}/modules/md5/md5.c"
  "${ROOT}/modules/md5/compat-5.2.c")
add_lua_module(regex
  "${ROOT}/modules/regex/lposix.c"
  "${ROOT}/modules/regex/common.c")
add_lua_module(xml "${ROOT}/modules/xml/xml.c")
add_lua_module(zlib "${ROOT}/modules/zlib/lua_zlib.c")
target_link_libraries(zlib z)
add_lua_module(mime "${ROOT}/modules/socket/mime.c")
target_include_directories(mime PRIVATE "${ROOT}/modules/socket")
add_lua_module(socket
  "${ROOT}/modules/socket/luasocket.c"
  "${ROOT}/modules/socket/timeout.c"
  "${ROOT}/modules/socket/buffer.c"
  "${ROOT}/modules/socket/io.c"
  "${ROOT}/modules/socket/auxiliar.c"
  "${ROOT}/modules/socket/options.c"
  "${ROOT}/modules/socket/inet.c"
  "${ROOT}/modules/socket/tcp.c"
  "${ROOT}/modules/socket/udp.c"
  "${ROOT}/modules/socket/except.c"
  "${ROOT}/modules/socket/select.c"
  "${ROOT}/modules/socket/usocket.c")
add_lua_module(gl
  "${ROOT}/modules/luagl/luagl.c"
  "${ROOT}/modules/luagl/luagl_const.c"
  "${ROOT}/modules/luagl/luagl_util.c")
target_compile_definitions(gl PRIVATE ANDROID_NDK DISABLE_IMPORTGL)
target_link_libraries(gl GLESv1_CM)
add_lua_module(sensor "${ROOT}/modules/sensor/luasensor.cpp")
target_include_directories(sensor PRIVATE "${ROOT}/modules/sensor")
target_compile_definitions(sensor PRIVATE LUA_COMPAT_APIINTCASTS)
target_compile_options(sensor PRIVATE -include "${COMPAT}/lua55_compat.h")
target_link_libraries(sensor android)
add_lua_module(tcc
  "${ROOT}/modules/tcc/tccpp.c"
  "${ROOT}/modules/tcc/libtcc.c"
  "${ROOT}/modules/tcc/tccelf.c"
  "${ROOT}/modules/tcc/tccasm.c"
  "${ROOT}/modules/tcc/tccgen.c"
  "${ROOT}/modules/tcc/tccrun.c"
  "${ROOT}/modules/tcc/arm-gen.c"
  "${ROOT}/modules/tcc/tcc_jni.c")
target_compile_definitions(tcc PRIVATE TCC_TARGET_ARM TCC_ARM_VFP TCC_ARM_EABI)
target_compile_options(tcc PRIVATE -std=gnu99 -Wno-pointer-sign -Wno-implicit-function-declaration)

set(ZIP_SRC "${ROOT}/modules/zip/lua_zip.c"
  "${ROOT}/modules/zip/mkstemp.c" "${ROOT}/modules/zip/zip_add.c" "${ROOT}/modules/zip/zip_add_dir.c" "${ROOT}/modules/zip/zip_add_entry.c" "${ROOT}/modules/zip/zip_buffer.c" "${ROOT}/modules/zip/zip_close.c" "${ROOT}/modules/zip/zip_delete.c" "${ROOT}/modules/zip/zip_dir_add.c" "${ROOT}/modules/zip/zip_dirent.c" "${ROOT}/modules/zip/zip_discard.c" "${ROOT}/modules/zip/zip_entry.c" "${ROOT}/modules/zip/zip_err_str.c" "${ROOT}/modules/zip/zip_error.c" "${ROOT}/modules/zip/zip_error_clear.c" "${ROOT}/modules/zip/zip_error_get.c" "${ROOT}/modules/zip/zip_error_get_sys_type.c" "${ROOT}/modules/zip/zip_error_strerror.c" "${ROOT}/modules/zip/zip_error_to_str.c" "${ROOT}/modules/zip/zip_extra_field.c" "${ROOT}/modules/zip/zip_extra_field_api.c" "${ROOT}/modules/zip/zip_fclose.c" "${ROOT}/modules/zip/zip_fdopen.c" "${ROOT}/modules/zip/zip_file_add.c" "${ROOT}/modules/zip/zip_file_error_clear.c" "${ROOT}/modules/zip/zip_file_error_get.c" "${ROOT}/modules/zip/zip_file_get_comment.c" "${ROOT}/modules/zip/zip_file_get_external_attributes.c" "${ROOT}/modules/zip/zip_file_get_offset.c" "${ROOT}/modules/zip/zip_file_rename.c" "${ROOT}/modules/zip/zip_file_replace.c" "${ROOT}/modules/zip/zip_file_set_comment.c" "${ROOT}/modules/zip/zip_file_set_external_attributes.c" "${ROOT}/modules/zip/zip_file_set_mtime.c" "${ROOT}/modules/zip/zip_file_strerror.c" "${ROOT}/modules/zip/zip_filerange_crc.c" "${ROOT}/modules/zip/zip_fopen.c" "${ROOT}/modules/zip/zip_fopen_encrypted.c" "${ROOT}/modules/zip/zip_fopen_index.c" "${ROOT}/modules/zip/zip_fopen_index_encrypted.c" "${ROOT}/modules/zip/zip_fread.c" "${ROOT}/modules/zip/zip_get_archive_comment.c" "${ROOT}/modules/zip/zip_get_archive_flag.c" "${ROOT}/modules/zip/zip_get_compression_implementation.c" "${ROOT}/modules/zip/zip_get_encryption_implementation.c" "${ROOT}/modules/zip/zip_get_file_comment.c" "${ROOT}/modules/zip/zip_get_name.c" "${ROOT}/modules/zip/zip_get_num_entries.c" "${ROOT}/modules/zip/zip_get_num_files.c" "${ROOT}/modules/zip/zip_io_util.c" "${ROOT}/modules/zip/zip_memdup.c" "${ROOT}/modules/zip/zip_name_locate.c" "${ROOT}/modules/zip/zip_new.c" "${ROOT}/modules/zip/zip_open.c" "${ROOT}/modules/zip/zip_rename.c" "${ROOT}/modules/zip/zip_replace.c" "${ROOT}/modules/zip/zip_set_archive_comment.c" "${ROOT}/modules/zip/zip_set_archive_flag.c" "${ROOT}/modules/zip/zip_set_default_password.c" "${ROOT}/modules/zip/zip_set_file_comment.c" "${ROOT}/modules/zip/zip_set_file_compression.c" "${ROOT}/modules/zip/zip_set_name.c" "${ROOT}/modules/zip/zip_source_begin_write.c" "${ROOT}/modules/zip/zip_source_buffer.c" "${ROOT}/modules/zip/zip_source_call.c" "${ROOT}/modules/zip/zip_source_close.c" "${ROOT}/modules/zip/zip_source_commit_write.c" "${ROOT}/modules/zip/zip_source_crc.c" "${ROOT}/modules/zip/zip_source_deflate.c" "${ROOT}/modules/zip/zip_source_error.c" "${ROOT}/modules/zip/zip_source_file.c" "${ROOT}/modules/zip/zip_source_filep.c" "${ROOT}/modules/zip/zip_source_free.c" "${ROOT}/modules/zip/zip_source_function.c" "${ROOT}/modules/zip/zip_source_is_deleted.c" "${ROOT}/modules/zip/zip_source_layered.c" "${ROOT}/modules/zip/zip_source_open.c" "${ROOT}/modules/zip/zip_source_pkware.c" "${ROOT}/modules/zip/zip_source_read.c" "${ROOT}/modules/zip/zip_source_remove.c" "${ROOT}/modules/zip/zip_source_rollback_write.c" "${ROOT}/modules/zip/zip_source_seek.c" "${ROOT}/modules/zip/zip_source_seek_write.c" "${ROOT}/modules/zip/zip_source_stat.c" "${ROOT}/modules/zip/zip_source_supports.c" "${ROOT}/modules/zip/zip_source_tell.c" "${ROOT}/modules/zip/zip_source_tell_write.c" "${ROOT}/modules/zip/zip_source_window.c" "${ROOT}/modules/zip/zip_source_write.c" "${ROOT}/modules/zip/zip_source_zip.c" "${ROOT}/modules/zip/zip_source_zip_new.c" "${ROOT}/modules/zip/zip_stat.c" "${ROOT}/modules/zip/zip_stat_index.c" "${ROOT}/modules/zip/zip_stat_init.c" "${ROOT}/modules/zip/zip_strerror.c" "${ROOT}/modules/zip/zip_string.c" "${ROOT}/modules/zip/zip_unchange.c" "${ROOT}/modules/zip/zip_unchange_all.c" "${ROOT}/modules/zip/zip_unchange_archive.c" "${ROOT}/modules/zip/zip_unchange_data.c" "${ROOT}/modules/zip/zip_utf-8.c")
add_lua_module(zip ${ZIP_SRC})
target_include_directories(zip PRIVATE "${ROOT}/modules/zip")
target_link_libraries(zip z)

file(GLOB LUV_SRC
  "${ROOT}/modules/luv/luv/luv.c"
  "${ROOT}/modules/luv/uv/*.c"
  "${ROOT}/modules/luv/uv/unix/android-ifaddrs.c"
  "${ROOT}/modules/luv/uv/unix/async.c"
  "${ROOT}/modules/luv/uv/unix/core.c"
  "${ROOT}/modules/luv/uv/unix/dl.c"
  "${ROOT}/modules/luv/uv/unix/fs.c"
  "${ROOT}/modules/luv/uv/unix/getaddrinfo.c"
  "${ROOT}/modules/luv/uv/unix/getnameinfo.c"
  "${ROOT}/modules/luv/uv/unix/linux-core.c"
  "${ROOT}/modules/luv/uv/unix/linux-inotify.c"
  "${ROOT}/modules/luv/uv/unix/linux-syscalls.c"
  "${ROOT}/modules/luv/uv/unix/loop.c"
  "${ROOT}/modules/luv/uv/unix/loop-watcher.c"
  "${ROOT}/modules/luv/uv/unix/pipe.c"
  "${ROOT}/modules/luv/uv/unix/poll.c"
  "${ROOT}/modules/luv/uv/unix/process.c"
  "${ROOT}/modules/luv/uv/unix/procfs-exepath.c"
  "${ROOT}/modules/luv/uv/unix/proctitle.c"
  "${ROOT}/modules/luv/uv/unix/pthread-fixes.c"
  "${ROOT}/modules/luv/uv/unix/signal.c"
  "${ROOT}/modules/luv/uv/unix/stream.c"
  "${ROOT}/modules/luv/uv/unix/sysinfo-loadavg.c"
  "${ROOT}/modules/luv/uv/unix/sysinfo-memory.c"
  "${ROOT}/modules/luv/uv/unix/tcp.c"
  "${ROOT}/modules/luv/uv/unix/thread.c"
  "${ROOT}/modules/luv/uv/unix/tty.c"
  "${ROOT}/modules/luv/uv/unix/udp.c"
  "${ROOT}/modules/luv/uv/fs-poll.c"
  "${ROOT}/modules/luv/uv/inet.c"
  "${ROOT}/modules/luv/uv/threadpool.c"
  "${ROOT}/modules/luv/uv/timer.c"
  "${ROOT}/modules/luv/uv/uv-common.c"
  "${ROOT}/modules/luv/uv/uv-data-getter-setters.c"
  "${ROOT}/modules/luv/uv/version.c")
add_lua_module(luv ${LUV_SRC})
target_include_directories(luv PRIVATE "${ROOT}/modules/luv/include" "${ROOT}/modules/luv/uv" "${ROOT}/modules/luv")
target_compile_definitions(luv PRIVATE _GNU_SOURCE)

file(GLOB YAML_SRC
  "${ROOT}/third_party/libyaml/src/*.c"
  "${ROOT}/third_party/lyaml/yaml/*.c")
add_lua_module(yaml ${YAML_SRC})
target_include_directories(yaml PRIVATE
  "${ROOT}/third_party/libyaml/include"
  "${ROOT}/third_party/libyaml/src"
  "${ROOT}/third_party/lyaml/yaml")
target_compile_definitions(yaml PRIVATE "YAML_VERSION_STRING=\"0.2.5\"" YAML_VERSION_MAJOR=0 YAML_VERSION_MINOR=2 YAML_VERSION_PATCH=5 "VERSION=\"0.1.3\"")

add_lua_module(threads
  "${ROOT}/third_party/llthreads2/src/llthread.c"
  "${ROOT}/third_party/llthreads2/src/l52util.c")
target_compile_definitions(threads PRIVATE LLTHREAD_MODULE_NAME=threads)
target_include_directories(threads PRIVATE "${ROOT}/third_party/llthreads2/src")
