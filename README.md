# Mini-LuaXPLUS

在 Android 上使用 Lua 语法编写应用的脚本编程工具：内置编辑器、布局表、LuaJava 桥接与打包安装能力。

- 应用名称：Mini-LuaXPLUS
- 应用包名：`com.mini.luaxplus`
- 运行平台：Android 5.0（API 21）及以上，目标版本 Android 12（API 31）
- 当前版本：`1.0.0-rc1`

## 技术架构

| 模块 | 职责 | 形态 |
| --- | --- | --- |
| `:app` | 编辑器外壳、主题、图标、打包入口 | Java + Lua 脚本 |
| `:androlua` | Lua 运行时（LuaActivity / LuaJava / 布局装载 / 打包） | 预编译 `libs/AndroLua+5.0.18_AndroidX.jar` + `libluajava.so` |
| `app/src/main/assets` | 编辑器全部界面与业务逻辑 | Lua 脚本（13k+ 行，`main.lua` 为主入口） |

运行时的 Java 实现位于二进制 jar 中，本仓库只包含少量扩展类：

- `app/src/main/java/com/mini/luaxplus/LuaMaterialDialog.java`：Material3 对话框桥接
- `androlua/src/main/java/com/androlua/LuaDialog.java`：对话框基类
- `androlua/src/main/java/androidx/appcompat/app/AlertControllerBridge.java`：AppCompat 对话框桥接

因此：Lua 层、资源层、少量 Java 扩展可以直接改；Lua 引擎、LuaJava 绑定、布局装载等底层能力需要拿到上游 Java 源码重新编译 jar 才能改。

## 目录说明

```
app/                     编辑器应用模块
  src/main/assets/       Lua 脚本、类库索引、帮助文档、插件与工程模板
  src/main/java/         扩展 Java 类
  src/main/res/          主题、颜色、图标
  src/main/jniLibs/      LuaJava 原生库（armeabi-v7a / arm64-v8a）
androlua/                 运行时封装模块（jar + 原生库 + 少量桥接类）
version.properties        版本号唯一来源
keystore.properties       本地签名配置（不入库）
keystore/                 正式签名密钥库（不入库）
app/proguard-rules.pro    R8 规则
docs/                     审计与规范文档
```

## 版本号规范

版本号只允许在 `version.properties` 修改：

```
VERSION_MAJOR=1
VERSION_MINOR=0
VERSION_PATCH=0
VERSION_STAGE=rc1
```

- 开发迭代：`VERSION_STAGE=rc1`、`rc2`……，版本名 `1.0.0-rc1`、`1.0.0-rc2`
- 正式版：`VERSION_STAGE=final`，版本名 `1.0.0`；**必须经项目负责人批准后才能改**
- `versionCode` 自动计算：`(major*10000 + minor*100 + patch)*100 + stage`，rcN 取 N（1–49），final 取 99
  - 例：`1.0.0-rc1` → `1000001`，`1.0.0` → `1000099`
  - 这样正式版的 versionCode 永远高于同版本的所有 rc，升级不会被拒
- Tag 命名：`v1.0.0-rc1`、`v1.0.0`，与 versionName 完全一致
- 破坏性改动升 minor，修复升 patch

## 签名规范

签名信息不写入仓库，按以下优先级读取：

1. 根目录 `keystore.properties`（本地开发）
2. 环境变量：`MINI_LUAXPLUS_KEYSTORE`、`MINI_LUAXPLUS_KEYSTORE_PASSWORD`、`MINI_LUAXPLUS_KEY_ALIAS`、`MINI_LUAXPLUS_KEY_PASSWORD`（CI）

`keystore.properties` 格式：

```
storeFile=keystore/mini-luaxplus-release.jks
storePassword=****
keyAlias=miniluaxplus
keyPassword=****
```

- debug 与 release 共用同一正式签名，避免安装覆盖冲突
- 启用 v1 / v2 / v3 三代签名
- 密钥库与密码必须离线备份，CI 侧使用 Secrets 注入

## 构建

```bash
./gradlew :app:assembleRelease
```

- 产物：`app/build/outputs/apk/release/app-release.apk`
- 需要 JDK 17 与 Android SDK Platform 34

## Android 12 及以上适配

- `targetSdkVersion = 31`，`compileSdk = 34`，`minSdk = 21`
- Android 11 起分区存储生效，传统工程目录需要“所有文件访问”：
  清单声明 `MANAGE_EXTERNAL_STORAGE`，首次启动由 `main.lua` 引导用户到系统设置授权
- 启动权限不再批量申请：`assets/init.lua` 提供 `check_permissions()` 钩子接管运行时默认的全量权限申请
- 所有组件显式设置 `android:exported`，避免 Android 12 安装期校验失败

## R8 说明

`app/proguard-rules.pro` 中保留运行时反射边界：

- `com.androlua.**`、`com.luajava.**`、`com.nirenr.**`、`com.baidu.**`、`bsh.**`、`com.android.cglib.**`
- `androidx.**`、`com.google.android.material.**`、`com.google.common.**`（Lua 脚本按类名动态加载）
- 资源表 `**R$*` 保留，避免脚本按 R 名称访问失败
- 资源压缩默认关闭：运行时 jar 以硬编码资源 ID 引用图片，开启后会缺资源

## 已知限制

- 运行时外部目录已由 `/storage/emulated/0/AndroLua` 改为 `/storage/emulated/0/LuaXPlus`：在 jar 的 `LuaApplication.class` 常量池中做等长字符串替换实现，未重编运行时
- `LuaApplication` 内的备用数据目录名同步为 `LuaXPlus`，属于应用私有目录，不影响用户可见路径
- 快捷方式图标资源 ID 在 jar 内仍是硬编码数字且与当前资源表错位，快捷方式功能需后续重写
- 部分第三方宿主兼容逻辑（`import "jesse205"`）是上游 Aide Lua 的模块契约，属于第三方 API 名称，予以保留
- 已移除随包的 AOSP `platform` / `testkey` 密钥，“平台签名打包”选项不再可用；常规打包使用应用内 `keystore.ks` 的调试签名

## 品牌资源

- `design/icon.svg`：图标矢量源文件（纸感底 + 墨蓝月牙 + 青色轨道）
- `app/src/main/res/drawable/icon.png`：供 Lua 侧 `R.drawable.icon` 与打包默认图标使用
- `app/src/main/res/mipmap-*`：桌面图标各密度切图与自适应图标前景
- `app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`：自适应图标声明
- `ic_launcher-aidelua.png` / `ic_launcher_night-aidelua.png`：Aide Lua 打包用的日间/夜间图标
- 启动页由 `app/src/main/java/com/mini/luaxplus/Welcome.java` 实现，展示品牌标识后进入编辑器，并保留版本变更提示

## 上游与许可

本项目在 AndroLuaX（MIT）基础上二次开发，技术底座来自 AndroLua / AndroLua+（作者 nirenr，基于 LuaJava）。相关版权与许可声明保留在 `LICENSE`。

本项目代码采用 MIT 许可，见 [LICENSE](LICENSE)。
