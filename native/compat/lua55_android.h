#ifndef MINI_LUAX_LUA55_ANDROID_H
#define MINI_LUAX_LUA55_ANDROID_H

/* 32 位 Android 21 没有 fseeko/ftello，退回 32 位文件定位 */
#if defined(__ANDROID__) && defined(__arm__) && !defined(l_fseek)
#define l_fseek(f, o, w) fseek((f), (o), (w))
#define l_ftell(f) ftell((f))
#define l_seeknum long
#endif

#endif
