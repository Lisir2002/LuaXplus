# Mini-LuaXPLUS

在 Android 上使用 Lua 语法编写应用的脚本编程工具：内置编辑器、布局表、LuaJava 桥接与打包安装能力。

- 应用名称：Mini-LuaXPLUS
- 应用包名：`com.mini.luaxplus`
- 运行平台：Android 5.0（API 21）及以上，目标版本 Android 12（API 31）
- 当前版本：`1.0.0-rc34`

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

## LuaX-UI 组件库

内置一套 iOS 风格的原生界面组件，放在 `app/src/main/assets/lua/luaxplus/ui.lua`，通过 `require "luaxplus.ui"` 使用。

- 纯增量：不修改 `import`、`luajava`、`LuaActivity`，不接管 `setContentView`，原生 View 可继续混用。
- 快捷 API：`ui.show` 一行建页面，`ui.form` 一行建表单并直接读写字段。
- 组件范围：页面骨架、分组列表、按钮、表单、搜索栏、分段控件、卡片、弹窗、操作菜单、底部标签栏、空态与加载态。
- 进阶组件：chip、checkRow、slider、stepper、progress、skeleton、banner、stat、fab、toast。
- 选择与数据：switch、switchRow、radioGroup、rating、select、keyValue、table、timeline、accordion、avatarGroup、pagination。
- 原子组件：text、label、helper、icon、surface、stack/vstack/hstack、grid、center、input、checkMark、checkbox、radioMark、statusDot、tabItem、cell、kvRow、fadeIn/slideIn/scaleIn。
- 设计令牌：`ui.tokens` 统一颜色、间距、圆角、字体、控件尺寸、动效和透明度；支持 `ui.defineTheme` 自定义主题、`ui.useTheme` 切换、`ui.cssVars` 导出 CSS 变量。
- 数值无级调节：尺寸、字号、圆角、透明度和动效都同时接受令牌档位与数值字符串，例如 `textSize="15px"`、`radius="14px"`、`withAlpha(..., "35%")`；`ui.dp`、`ui.number`、`ui.metric` 可直接复用解析器。
- 图片与背景：`ui.image` 支持本地/网络路径、Bitmap/Drawable、圆角、圆形、缩放和透明度；`ui.background` 支持图片铺底、遮罩、圆角和内容叠加；`ui.page` 支持整页背景图。
- 透明度：`ui.tokens.opacity` 提供 14 档刻度，`ui.withAlpha` 接受 0-1、0-255、百分比或令牌名，适合遮罩、状态色和文字压图。
- 动画：`ui.animate`、`ui.stagger`、`ui.press` 与 `page:reveal`，默认 260ms 上移淡入。
- 自绘开关：`app/src/main/java/com/mini/luaxplus/ui/IosSwitch.java`，失败时自动回退系统 `Switch`。
- 打包携带：`assets/lua/luaxplus/` 在打包白名单内，新打包的成品会自动带上组件库；已安装的旧成品需重新打包。
- 教程：应用内“手册 → LuaX-UI 组件库”，含字段表、设计令牌、自定义主题与可直接运行的完整页面示例。

## 编辑器保存前审计

编辑器保存、另存为和退出保存前会检查当前 Lua 文件，重点拦住“调用了 `ui` 却没有 `require`”这类运行期才报 nil 的问题。

- 当前文件：识别已知库引用缺失，弹窗可“一键补全”“仍然保存”或取消。
- 工程范围：扫描项目内全部 `.lua` 文件顶层定义，跨文件调用不再误报未定义。
- 细提示：未使用局部变量、拼写建议、作用域遮蔽和声明前使用；编辑器菜单“代码检查”可随时查看。
- 自研库：支持项目 `lua/lint-libs.lua` 清单、`lua/` 或 `lib/` 目录自动发现，以及 `lint.registerLibrary` 注册，不用改审计核心。
- 边界：静态分析不执行代码，动态全局和通配符 import 只做低置信提示，不强制阻断保存。

详细规则和接入方式见 `docs/editor-audit.md`。

## 权限管理

- 设置 → 权限管理打开独立页面，页面会读取当前安装包的全部 `requestedPermissions`，按存储、网络、通知、位置、相机、联系人、短信、附近设备、特殊访问分组展示。
- 首次启动只申请存储：Android 11+ 跳到“所有文件访问”，低版本申请读写存储；网络属于普通权限，安装时由系统授予。
- 其他运行时权限不会在启动时自动弹窗，页面里可逐项申请；特殊权限（所有文件访问、修改系统设置、安装未知应用、勿扰模式、无障碍）只能跳转对应系统页开启。
- “一键申请”批量提交运行时权限；“一键关闭”打开系统应用权限页，由用户确认撤销；系统不允许应用静默撤销运行时权限。

## 页面主题与系统栏

- 页面统一从 `assets/lua/luaxplus/theme.lua` 取纸感色板，不再各自写死主背景、卡片和强调色。
- `theme.apply(activity, options)` 统一状态栏、导航栏和窗口底色：清除半透明遮罩、页面顶部与状态栏同色、页面底部与导航栏同色，并同步深浅色图标。
- `ui.page` 默认把状态栏和页面导航栏都铺成页面底色；`theme.install(ui)` 可把组件库切到 `paper` 纸感主题，后续换肤只需改主题令牌。

## 官方示例

首页侧边栏新增「官方示例」入口，进入后是与项目列表同款的示例卡片。

- 示例源码位于 `app/src/main/assets/examples/`，首次打开会铺设到 `LuaXPlus/examples`。
- 自建工程只存放在 `LuaXPlus/project`，两边目录与列表完全隔离，删除或改名互不影响。
- 示例工程和普通工程一样，可以进入属性页、目录页编辑文件、运行和打包。
- 官方示例合并为一个工程，第一个页签「快速」用几十行演示 `ui.show` 与 `ui.form`，其余页签覆盖控件、表单、弹窗、进阶组件与动画。


## Java API 浏览器

首页侧栏「Java 浏览器」打开内置的 Java API 浏览器，数据来自安装包里的 Android 与 AndroidX/Material 类索引，不依赖网络。

- 类索引：合并两份本地索引并去重，过滤 `package-info` 占位类，当前共 6385 个可搜索类。
- 搜索：支持类名、简单类名和包名的多关键词、不区分大小写筛选；带清空按钮和结果计数，输入有 120ms 防抖。
- 类详情：点击类进入全屏详情，按构造方法、事件、getter、setter、字段和公有方法分类；签名由反射对象生成，不再直接打印 `toString`。
- 复制：长按类复制完整类名，长按成员复制方法或字段名；详情页右上角可直接复制类名。
- 异常保护：类无法在当前 ROM/依赖中加载时只提示，不再崩溃；空搜索结果有独立空态。
- 视觉：接入纸感主题和系统栏，搜索框、列表、空态和详情页与设置/手册页面统一。

## 使用手册

首页侧栏新增「使用手册」入口，直接打开安装包内置的离线手册。

- 手册首页按「先读这三页 / 常用任务 / 全部章节」组织，支持关键词筛选与全局搜索。
- 宽屏使用固定侧栏，手机上使用抽屉；正文带本页目录、阅读进度、上一页/下一页与返回顶部。
- 语言参考页保留原有 Lua 5.3 正文，统一顶栏、目录和代码块样式，不依赖网络。

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
- 构建前自动执行 `:app:luaCheck`：Lua 语法检查 + JavaAPI 严格契约测试，不需要模拟器
- 单独运行：`./gradlew :app:luaCheck`；详细说明见 `tools/lua-check/README.md`

## 应用内打包预检

应用内点“打包”时，`bin.lua` 会先调用 `packcheck` 只读检查工程，再进入压缩、签名和安装：

- 必须存在入口 `main.lua`
- 所有 `.lua` 文件必须通过语法编译
- 所有 `.aly` 布局必须能解析成 Lua 布局表
- 任一检查失败都会直接返回错误清单，不生成 APK

预检只拦语法问题；JavaAPI 这类运行期方法调用错误由构建阶段的 `luaCheck` 契约测试覆盖。

## Android 12 及以上适配

- `targetSdkVersion = 31`，`compileSdk = 34`，`minSdk = 21`
- Android 11 起分区存储生效，传统工程目录需要“所有文件访问”：
  清单声明 `MANAGE_EXTERNAL_STORAGE`，首次启动只主动申请存储；网络为普通权限，安装时由系统授予
- 其余敏感权限不再随启动批量申请；设置页新增独立“权限管理”，可全量查看、批量申请运行时权限、跳转系统设置或打开应用权限页关闭
- 首次存储申请记录在 SharedPreferences，后续启动不重复检查权限或弹窗
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

## 启动引导与日志

启动流程：`Welcome` 先初始化日志与运行监控，再把 assets 内的脚本铺设到应用私有目录，最后进入 `Main`。铺设带版本标记 `.luaxplus_bootstrap`，版本变化或入口脚本缺失时自动重铺，避免出现“找不到 main.lua”。

日志统一写入外部存储的 `LuaXPlus/logs`，未获得存储授权时先写应用私有目录 `files/logs`，授权后自动切回外部目录。

| 文件 | 用途 |
| --- | --- |
| `app_yyyyMMdd.log` | 运行日志，按天切分，单文件超过 2MB 转为 `app_yyyyMMdd_2.log` |
| `crash_yyyyMMdd_HHmmss_进程号.log` | Java 层未捕获崩溃，含完整堆栈与设备信息 |
| `luaerror_yyyyMMdd_HHmmss.log` | Lua 层错误，含 traceback |

日志行格式：`2026-11-22 07:12:33.123 I/Main(1234) 内容`，字段依次为时间、级别、来源、进程号、正文。级别为 `D/I/W/E`。

保留策略：超过 7 天的文件在启动时清理，目录内最多保留 40 个文件。

覆盖范围：启动与页面生命周期、Activity 跳转意图、脚本铺设、模块与类导入、`print` 控制台输出、存储权限检查、版本变更提示、Java 崩溃、Lua 错误。

在脚本里写日志：

```lua
local log = require "luaxplus.log"
log.i("demo", "启动完成")
log.e("demo", "出错了", err)
```

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
