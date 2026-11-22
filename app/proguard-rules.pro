# Mini-LuaXPLUS 混淆与压缩规则
# 运行时会按类名动态加载 AndroidX / Material 组件，反射边界必须整体保留，
# 否则 Lua 脚本运行时会找不到类。

# ---- 运行时与脚本引擎 ----
-keep class com.androlua.** { *; }
-keep class com.luajava.** { *; }
-keep class com.nirenr.** { *; }
-keep class com.baidu.** { *; }
-keep class bsh.** { *; }
-keep class com.android.cglib.** { *; }
-keep class org.luaj.** { *; }

# ---- 供 Lua 动态引用的框架组件 ----
-keep class androidx.** { *; }
-keep class com.google.android.material.** { *; }
-keep class com.google.common.** { *; }

# ---- 运行时 jar 内自带的 android 包扩展类 ----
# 这些类不在系统框架里，是运行时随包提供的组件，脚本按原始类名加载
-keep class android.widget.** { *; }
-keep class android.app.** { *; }
-keep class android.content.** { *; }

# ---- 本应用自有类 ----
-keep class com.mini.luaxplus.** { *; }

# ---- 反射、JNI 与脚本桥接 ----
-keepclasseswithmembernames class * { native <methods>; }
-keepclassmembers enum * { *; }
-keepclassmembers class * { @android.webkit.JavascriptInterface <methods>; }
-keepclassmembers class * implements android.os.Parcelable { public static final ** CREATOR; }

# ---- 元数据（脚本反射依赖签名、注解与内部类信息） ----
-keepattributes Signature,*Annotation*,InnerClasses,EnclosingMethod,Exceptions,SourceFile,LineNumberTable

# ---- 资源表禁止混淆，供脚本按 R 名称访问 ----
-keep class **.R$* { *; }

# 脚本通过字符串按原始类名、方法名访问对象，关闭改名避免运行时找不到成员
-dontobfuscate

-dontwarn **
-ignorewarnings

-keep class com.android.apksig.** { *; }
-keep class com.mini.luaxplus.PackSigner { *; }

# 脚本通过反射调用文本定位工具，需保留类与方法名
-keep class com.mini.luaxplus.TextUtil { public static *; }
