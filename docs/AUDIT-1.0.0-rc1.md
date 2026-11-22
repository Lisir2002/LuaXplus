# Mini-LuaXPLUS 基线审计报告（1.0.0-rc1）

审计日期：2026-11-22　审计对象：AndroLuaX（main 分支，29 commits）

## 一、结论摘要

1. 这是一个「薄壳 + 二进制运行时」的工程：界面与业务逻辑全部在 Lua 脚本里，Lua 引擎与 LuaJava 绑定在预编译 jar 中，没有对应源码。可改边界清晰，但底层能力无法直接修改。
2. 品牌并不只出现在配置里，而是分布在 5 个层次：Gradle 配置、Android 清单、Java 包路径、资源样式名、Lua 脚本文案，需要逐层替换，其中资源样式名被 Lua 通过 `R.style.*` 直接引用，改名必须同步。
3. 原工程无法在非作者机器上构建：签名指向作者本机 Windows 盘符路径，密码明文写死。
4. 原工程在 Android 12+ 上必然踩坑：`targetSdk=29`、依赖传统外部存储目录、启动时一次性申请清单内全部权限。
5. 该工程对 R8 非常敏感：Lua 脚本按类名动态加载组件，资源 ID 还被 jar 以硬编码数字引用，压缩规则必须覆盖这些边界。

## 二、工程构成

| 模块 | 内容 | 规模 |
| --- | --- | --- |
| `:app` | 编辑器外壳 | AGP 8.1.1 / Gradle 8.3，compileSdk 34，minSdk 21，targetSdk 29 |
| `:androlua` | 运行时库 | `libs/AndroLua+5.0.18_AndroidX.jar`（961 个 class，2.1MB 解压后）+ `libluajava.so`（arm64-v8a、armeabi-v7a） |
| `app/src/main/assets` | 编辑器全部逻辑 | 53 个文件，Lua 13,373 行；`main.lua` 55KB 为界面主入口 |
| Java 源码 | 仅 3 个类 | `LuaMaterialDialog`、`LuaDialog`、`AlertControllerBridge` |

运行时 jar 内含：`com.androlua.*`（Activity/Context/引擎/打包）、`com.luajava.*`（Lua 桥接）、`com.nirenr.*`（截屏）、`bsh.*`（BeanShell）、`com.android.cglib.*`（dex 生成）、`com.baidu.mobstat.*`（统计）。

## 三、运行时二进制边界（不可直接修改的部分）

反编译核验到的行为：

1. `LuaApplication.onCreate()` 将外部目录写死为 `Environment.getExternalStorageDirectory()/AndroLua`，全应用的工程、插件、备份、字体、临时目录都基于它。
2. `Welcome` 启动页把 `Powered by AndroLua+` 以逐字符常量形式写在字节码里，字符串替换无法消除。
3. `LuaActivity.createShortcut()` 使用硬编码资源 ID `2130771968`，另有 `2130771969` 作为默认图；这类数字 ID 依赖资源表顺序，新增/删除资源有错位风险。
4. `LuaActivity`、`LuaActivityX`、`Main`、`LuaService`、`LuaAccessibilityService` 都在 jar 内，清单只能引用，无法替换实现。

## 四、品牌更迭映射

| 位置 | 原值 | 新值 | 说明 |
| --- | --- | --- | --- |
| Gradle 工程名 | `AndroLuaX` | `Mini-LuaXPLUS` | `settings.gradle` |
| applicationId / namespace | `com.jesse205.androlua.androidX.material3` | `com.mini.luaxplus` | 两者统一 |
| 应用标签 | `AndroLuaX` | `Mini-LuaXPLUS` | 清单与无障碍服务标签 |
| Java 包 | `com.jesse205.androluax` | `com.mini.luaxplus` | `LuaMaterialDialog` 迁移 |
| 资源样式 | `Theme.AndroLuaX.Material3` 等 | `Theme.MiniLuaXPLUS.Material3` 等 | 资源名带连字符会非法，故去连字符 |
| Lua 取主题 | `R.style.Theme_AndroLuaX_Material3` | `R.style.Theme_MiniLuaXPLUS_Material3` | `autotheme.lua` |
| Lua 绑定 R | `com.jesse205...material3.R` | `com.mini.luaxplus.R` | `import.lua` |
| 界面文案 | “AndroLua+ / AndroLuaX / Jesse205” | “Mini-LuaXPLUS” | `main.lua`、`help.lua`、工程模板 |
| 华为平行视界配置 | 旧 client / 旧 Activity 名 | `com.mini.luaxplus` / `com.androlua.LuaActivityX` | `easygo.json` |

保留未改（属于第三方契约或二进制内部标识）：

- `import "com.androlua.*"`：jar 内类名，改则全崩
- `import "jesse205"`：Aide Lua 宿主模块契约，属第三方 API
- 外部目录名 `AndroLua`、启动页文案、jar 内其余字符串

## 五、安全隐患

| 等级 | 问题 | 处置 |
| --- | --- | --- |
| 高 | 签名密钥硬编码（Windows 路径 + 明文口令） | 改为 `keystore.properties` / 环境变量注入，密钥不入库 |
| 高 | 清单申请 `INSTALL_PACKAGES`、`WRITE_SETTINGS`、`READ_SMS`、`SEND_SMS`、`READ_CALL_LOG`、`GET_TASKS` 等 60+ 项权限 | 本次先接管申请流程（不再首启批量弹窗），后续按功能裁剪清单 |
| 中 | `usesCleartextTraffic=true`，允许明文 HTTP | 保留（脚本工具需访问任意站点），后续可加白名单 |
| 中 | 运行时加载外部 dex（`mao.dex`、`sign.dex`、`loadDex`） | 属打包/签名能力，保留但需在文档标注风险 |
| 中 | 内置百度统计 SDK | 保留现状，后续评估是否移除 |
| 低 | `allowBackup=true`，备份可导出数据 | 后续按需关闭 |

## 六、Android 12+ 适配

| 风险点 | 结论 | 处置 |
| --- | --- | --- |
| 分区存储（Android 10+ 限制、11+ 强制） | 外部工程目录直接不可写 | 声明 `MANAGE_EXTERNAL_STORAGE`，首启引导授权；未授权时给出明确提示 |
| 首启批量权限申请 | 体验灾难且多数被拒 | `assets/init.lua` 提供 `check_permissions()` 返回 true 接管，改由 `main.lua` 按需申请 |
| PendingIntent 可变性（Android 12 强制） | 反编译未发现 `PendingIntent` 调用 | 无需处理 |
| `android:exported`（Android 12 强制） | 清单中带 intent-filter 的组件已显式声明 | 保持 |
| 通知权限（Android 13 起） | targetSdk 31 不触发 | 后续升 33 时需补 `POST_NOTIFICATIONS` |
| 前台服务类型（Android 14 起） | targetSdk 31 不触发 | 后续升 34 时需补 `foregroundServiceType` |

本次 `targetSdk` 定为 31（Android 12 基线），`compileSdk` 34。升 33/34 需要追加通知权限与前台服务类型适配，单独排期。

## 七、R8 风险

| 风险 | 说明 | 规则处置 |
| --- | --- | --- |
| 按类名动态加载 | Lua 用 `import "androidx.xxx.YYY"` 在运行时查找类 | `-keep class androidx.**`、`com.google.android.material.**`、`com.google.common.**` |
| 反射调用 | LuaJava 通过反射调方法/字段 | 保留 `com.androlua.**`、`com.luajava.**`、`com.nirenr.**`、`bsh.**`、`com.android.cglib.**` |
| 资源按名字访问 | 脚本用 `R.style.*`、`R.drawable.*` | `-keep class **.R$*` |
| 资源 ID 硬编码 | jar 内 `2130771968/2130771969` | 关闭资源压缩（`shrinkResources=false`），避免资源被移除或错位 |
| JNI | `libluajava.so` 绑定 Java 方法 | `-keepclasseswithmembernames class * { native <methods>; }` |

## 八、版本与签名

- 版本唯一来源：`version.properties`；`versionCode = (major*10000+minor*100+patch)*100 + stage`，rcN 取 N，final 取 99
- 1.0.0-rc1 → `versionCode 1000001`，`versionName 1.0.0-rc1`
- 正式版 1.0.0 → `versionCode 1000099`，需人工批准后修改 `VERSION_STAGE=final`
- 签名：debug 与 release 共用正式签名；启用 v1/v2/v3；本地 `keystore.properties`，CI 环境变量

## 九、验证清单

- [ ] `:app:assembleRelease` 构建通过
- [ ] APK 包名 `com.mini.luaxplus`、版本 `1.0.0-rc1` / `1000001`
- [ ] `apksigner verify` 通过 v1/v2/v3
- [ ] APK 体积与基线对比
- [ ] 安装启动、编辑器可打开、打包功能可用（需真机）
- [ ] Android 12 设备首启引导授权、工程目录可读写（需真机）
- [ ] Android 12 以下设备权限申请正常（需真机）

## 十、待办

1. 应用图标仍为上游图标，需替换为新品牌视觉
2. 启动页 “Powered by AndroLua+” 需自建 Welcome 或重编运行时才能消除
3. 外部目录名 `AndroLua` 待重编运行时后改名
4. 权限清单按功能裁剪，移除不需要的高危权限
5. 如后续要改 Lua 引擎/布局装载，需要引入上游 Java 源码重建 jar

## 十一、构建验证结果（2026-11-22）

| 检查项 | 结果 |
| --- | --- |
| `:app:assembleRelease` | 通过（Gradle 8.3 / AGP 8.1.1 / JDK 17 / Platform 34） |
| 包名 | `com.mini.luaxplus` |
| 版本 | `1.0.0-rc1` / `versionCode 1000001` |
| 应用标签 | `Mini-LuaXPLUS` |
| minSdk / targetSdk | 21 / 31 |
| 签名 | v1、v2、v3 全部通过，RSA 4096，证书 SHA-256 `22:E6:E8:A2:81:F4:05:B1:C6:87:F9:14:7D:CC:6D:AC:A1:69:1B:B0:9B:BF:DB:64:A9:1F:28:B6:10:2B:2D:F0` |
| APK 体积 | 11MB（未压缩基线 6.1MB，增量来自 R8 保留规则） |
| 关键类保留 | `LuaActivity`、`LuaApplication`、`LuaDialog`、`LuaState`、`com.mini.luaxplus.R$style`、`LuaMaterialDialog`、`ScreenCaptureActivity` 均在 |
| 新增 Lua 代码 | `luac5.3 -p` 语法通过（`main.lua` 整体存在上游 `!=` 方言写法，非本次引入） |

构建过程中发现并修复的问题：

1. R8 规则文件最初放在工程根目录，AGP 只读取模块目录的 `proguard-rules.pro`，导致第一版 APK 把 `R$*`、`LuaDialog`、`LuaMaterialDialog` 全部裁掉；已迁移到 `app/proguard-rules.pro`。
2. 复核确认 jar 内硬编码资源 ID `0x7f010000` 在当前资源表中指向 `anim/abc_fade_in`，并非图标资源；说明上游的快捷方式图标引用本身就是错位的，属于继承缺陷，待后续替换创建快捷方式实现。
3. `:androlua` 与 `:app` 各自带了一份 `lua/import.lua` 等同名资源，打包时以 app 侧为准，构建有重复路径告警；后续需合并去重。

## 十二、补充发现：内置签名材料

`app/src/main/assets/keys/` 随包携带 7 个签名材料：

- `platform.pk8` / `platform.x509.pem` / `platform.sbt`
- `testkey.pk8` / `testkey.x509.pem` / `testkey.sbt`
- `keystore.ks`

这是 AOSP 公开的 platform / testkey 测试密钥，用于“打包 APK 并签名”功能中的系统级签名选项。风险与处置：

1. 这些密钥随 APK 分发，任何人可直接提取，不符合“密钥不得入库/随包”的安全要求。
2. 但它们属于公开的 AOSP 测试密钥，本身不构成私密信息泄露；真正风险在于被用于在信任 platform 证书的设备上伪造系统签名。
3. 处置建议：从 assets 移除 `platform.*`、`testkey.*`，打包功能仅保留用户自备密钥；若必须保留该能力，改为首次使用时由用户导入，不随包分发。
4. 本次未移除，因为会直接切断“平台签名打包”功能，需要产品层面确认后再动。

## 十三、四项处置结果（第二轮）

| 项 | 采纳方案 | 实施 | 验证 |
| --- | --- | --- | --- |
| 应用图标 | 重绘新品牌图标 | `design/icon.svg` 源文件 + 自适应图标 + 5 档密度切图 + 暗色打包图标 | 构建后 `aapt2 dump badging` 图标指向 `mipmap/ic_launcher` |
| 启动页 | 自建 Welcome 替换 | 新增 `com.mini.luaxplus.Welcome`，展示标识与标语后进入编辑器，保留版本变更提示 | 清单启动项已切换，jar 内置 Welcome 不再被引用 |
| 外部目录 | 运行时常量等长替换 | `LuaApplication.class` 中 `/AndroLua`→`/LuaXPlus`、`AndroLua`→`LuaXPlus`，字节长度不变（7971 字节），条目 1011 个完整保留 | `javap` 复核常量已变更，zip 结构重建后 961 个 class 全部在 |
| 内置平台密钥 | 移除随包 AOSP 密钥 | 删除 `platform.*`、`testkey.*` 共 6 个文件，保留 `keystore.ks` 作为默认打包签名 | `assets/keys` 仅剩 `keystore.ks` |

补充说明：

1. 目录改名只动了常量字符串，没有改类结构、方法签名或偏移，风险面最小；旧目录 `/storage/emulated/0/AndroLua` 不再被创建。
2. 因新包名本身是全新安装，不存在旧目录数据迁移问题。
3. `sign.dex` 仍保留 `platform` / `testkey` 的名称分支，缺少密钥时该模式会报错，常规打包不受影响。
4. 启动页替换后，jar 内 `Welcome` 的权限批申请与版本检查逻辑同时失效，权限改由 `main.lua` 自检接管，版本变更提示由自有启动页写入 extras 后交给 `Main`。

## 十四、启动失败根因与日志体系

### 根因

首次启动报 `Unknown error 7: cannot open /data/user/0/com.mini.luaxplus/files/main.lua`。反查运行时字节码确认：

1. `com.androlua.Main.getLuaPath()` 返回 `getLocalDir() + "/main.lua"`，`getLocalDir()` 即应用私有目录 `files`。
2. `LuaActivity.onCreate` 直接用 `doFile(path)` 走 `LuaState.LloadFile`，没有 assets 回退逻辑。
3. `LuaApplication.onCreate` 只创建外部目录与计算搜索路径，不铺设 assets。
4. 原启动页 `com.androlua.Welcome` 只读取 assets 里的 `init.lua` 取应用配置，同样不铺设。

结论：这套运行时假定“入口脚本已在私有目录”，而 Gradle 构建的 APK 从未提供该步骤，因此新装必失败。

### 处置

- 新增 `AssetBootstrap`：启动页在后台线程把 assets 递归复制到私有目录，跳过 `keys` 与 `*.dex`；写入 `.luaxplus_bootstrap` 版本标记，版本变化或入口缺失时重铺。
- `app/build.gradle` 与 `androlua/build.gradle` 增加 `assets.srcDirs += ['src/main/resources']`，让 `resources/lua` 下的 `import.lua`、`console.lua` 等运行时模块真正进入 assets，铺设后可由 `luadir/lua/?.lua` 命中。
- 入口脚本改为两层：`main.lua` 负责接管日志与统一捕获错误，原主体迁移为 `mainbody.lua` 由 `require` 加载。

### 日志体系

| 层 | 实现 | 覆盖 |
| --- | --- | --- |
| Java 落盘 | `LogCore` | 统一行格式、按天切分、2MB 滚动、7 天/40 文件保留、外部不可写回退私有目录并在授权后切换 |
| Java 监控 | `RuntimeWatcher` | 默认未捕获异常处理、Activity 生命周期与 Intent |
| Lua 侧 | `assets/luaxplus/log.lua` | `print` 与控制台输出、`import` 调用、主动上报、错误堆栈落 `luaerror` 文件 |

日志目录：外部 `LuaXPlus/logs`；未授权时 `files/logs`。命名规则见 README。

## 十五、R8 改名导致的运行时类找不到

首次进入编辑器时报 `Class not found: android.widget.ArrayListAdapter`，日志定位到 `import.lua` 的 `import_require`。

原因：`android.widget.ArrayListAdapter` 等类由运行时 jar 自带（不在系统框架内），R8 将其保留但改了名（`mapping.txt` 显示映射为 `d.b`），而脚本按原始类名反射加载，改名后必然找不到。

处置：

1. 补充保留规则 `android.widget.**`、`android.app.**`、`android.content.**`，覆盖 jar 自带扩展类。
2. 增加 `-dontobfuscate`。该工程几乎全部界面与业务由 Lua 脚本按字符串调用 Java，改名会持续制造同类问题；关闭改名后保留代码压缩与资源裁剪能力。
3. 复核 961 个 jar 类全部进入 dex，仅 23 个第三方聚合类被压缩移除，均无脚本引用。

体积维持 11MB，签名与版本不变。

## 十六、脚本残留与选择监听绑定

### 现象

重装同版本号 APK 后，运行日志报 `mainbody.lua:2294: com.androlua.LuaEditor@OnSelectionChangedListener is not a field`，但安装包内同一行已加保护。

### 原因

1. 铺设标记只用 `versionName` 判断，同版本重装时命中“已就绪”分支，私有目录继续使用首次安装铺进去的旧脚本，新包里的脚本没生效。
2. `LuaEditor` 只暴露 `setOnSelectionChangedListener(b.b.a.a.e)`，没有 `OnSelectionChangedListener` 字段，脚本按字段赋值必然抛出 `is not a field`。

### 处置

- 铺设指纹改为 `versionName + lastUpdateTime`，同版本重装也会重新铺设并覆盖旧脚本。
- 选择监听改为反射取 setter 参数类型，再用 `luajava.new(接口, {回调})` 创建代理，通过 `editor.setOnSelectionChangedListener(代理)` 绑定；整个过程仍在 `pcall` 内，失败只记警告不阻断启动。

## 十七、用户脚本运行缺少基础模块

点击运行后报 `/storage/emulated/0/LuaXPlus/new.lua:1: module 'import' not found`，搜索路径里出现 `/data/user/0/com.mini.luaxplus/app_lua/import.lua`。

原因：`LuaApplication.getLuaLpath()` 由 `getDir("lua")`（即 `app_lua`）构造，用户脚本的 `package.path` 只包含工程目录与 `app_lua`，不含主界面使用的 `files` 目录。铺设逻辑只把脚本复制到 `files`，`app_lua` 是空的。

处置：启动铺设时额外把 `assets/lua` 复制到 `context.getDir("lua")`，使 `import`、`loadlayout`、`console` 等基础模块在用户工程运行时也能被 `require` 命中。

## 十八、错误快照覆盖不全

现象：只有入口脚本错误会生成 `luaerror_*` 文件，用户脚本运行报错、运行时错误页都不产生新快照，旧文件时间停在首次报错那一刻。

原因：

1. `LuaActivity.sendError` 会先调用脚本全局 `onError(name, error)`，返回 true 才抑制默认错误页。用户脚本在独立 Lua 状态中执行，没有装载我们的日志钩子，所以只弹页面不落文件。
2. 入口包装层只在 `main.lua` 生效，覆盖不到其他脚本。

处置：

- `import.lua` 末尾注册全局 `onError`：写入 `luaerror` 快照后返回 false，保留原有错误页展示。绝大多数脚本都会 `require "import"`，可覆盖模板与用户工程。
- `RuntimeWatcher` 增加错误页兜底扫描：页面恢复前台时检查视图树，若出现 `Runtime error` 文本则整段截取存快照，覆盖未加载 import 的脚本。
- 快照文件名精确到毫秒（`luaerror_yyyyMMdd_HHmmss_SSS.log`），3 秒内完全相同的错误只记入运行日志，避免同一错误刷出大量文件。

## 十九、打包流程缺少 mao、sign 组件

现象：点打包后报 `Invalid method call ... /data/user/0/com.mini.luaxplus/files/mao not found`，堆栈落在 `import.lua:216 compile` 与 `bin.lua:56`。

原因：打包功能由 `bin.lua` 驱动，它依次 `compile "mao"`、`compile "sign"`。`compile` 转调 `loadDex(name)`，只在应用私有目录按无扩展名查找 `files/mao`、`files/sign`；而工程里这两个组件以 `assets/mao.dex`、`assets/sign.dex` 形式存在，启动铺设时被 `.dex` 后缀规则整体跳过，导致文件始终缺失。

处置：

- 启动铺设阶段单独把 `assets/mao.dex` 复制为 `files/mao`、`assets/sign.dex` 复制为 `files/sign`，安装后强制覆盖，保证组件与安装包一致。
- 打包最后一步 `Signer.sign` 固定从 `assets/keys/` 取密钥，候选为 `platform`、`testkey`。平台密钥维持移除状态；恢复 AOSP 公开测试密钥 `testkey`（`.pk8`/`.x509.pem`/`.sbt`），仅用于本机打包调试，不涉及品牌私钥，也不具备系统平台权限。
- “平台签名打包”选项仍不可用，属预期行为。

## 二十、打包成品提示与系统不兼容

现象：打包成功并自动弹出安装界面，但系统提示“安装应用与当前系统有兼容性问题，建议联系开发者后重试”。

原因：打包器以本应用自身 APK 作为模板替换脚本，模板的目标系统版本为 31。内置签名组件只生成传统的 v1 签名，而目标版本 30 及以上的应用必须携带 v2 或更高版本签名，系统因此直接拒绝安装，与代码和权限无关。

处置：

- 新增 `PackSigner`（`com.mini.luaxplus.PackSigner`）：在设备上用 apksig 完成 v1 + v2 + v3 三段签名，密钥复用工程内置的公开测试密钥，写入临时文件后再落位，避免半成品。
- 打包脚本签名环节改为优先调用 `PackSigner`，异常时回退旧组件，保证旧环境仍能出包。
- 引入脱糖支持，使签名库依赖的新版 Java 接口在低版本系统上可用；签名库与签名类加入保留规则，避免被压缩改名。
- 实测：用同一把测试密钥对我方安装包签名，验签结果 v1/v2/v3 均为 true。

## 二十一、成品归档不符合系统要求

现象：签名已是 v1 + v2 + v3，验签全部通过，系统仍提示“安装应用与当前系统有兼容性问题”。

原因：打包器把所有条目都用压缩方式写回压缩包，包括资源表 `resources.arsc`。目标版本 30 及以上的安装包，系统要求资源表必须不压缩且按四字节对齐，否则在解析阶段直接拒绝安装。前一节只补了签名，没有处理归档本身。

处置：

- 新增 `ApkPreparer`：签名前先重排归档，资源表改为不压缩写入，并用规范占位的附加信息补齐到四字节边界；同时丢弃旧的签名文件，避免残留互相冲突。
- `PackSigner` 的流程改为“整理归档 → v1 + v2 + v3 签名 → 落位”。
- 实测：对用户提供的失败成品重排后签名，`zipalign` 四字节对齐检查通过、验签通过、资源表读取正常。

## 二十二、成品包启动崩溃与日志注入

现象：成品包可以安装，但一打开就报 `module 'import' not found`，搜索路径包含私有目录 `files/lua`、`app_lua`，而这两个位置都是空的。

原因：打包器以本应用安装包为模板，但复制模板条目时把所有 `assets/` 全部跳过，只写入了项目自身的脚本。成品包因此缺少运行时基础模块（`assets/lua`）、日志脚本（`assets/luaxplus/log.lua`），启动铺设复制不出 `import` 等模块，脚本第一行加载就失败。

处置：

- 打包器保留模板中的 `assets/lua/` 与 `assets/luaxplus/`，项目自身同名文件仍然优先覆盖；成品包由此获得完整运行时模块与日志脚本。
- 日志目录按身份分流：主程序写入 `LuaXPlus/logs`，成品写入 `LuaXPlus/products/<包名>/logs`，互不干扰，便于按产品排查。
- 新增警告快照：`warn_日期_时分秒_毫秒_进程号.log`，同一警告 5 秒内只留首条，控制文件数量。
- 成品包启动时申请存储授权（Android 11 及以上走所有文件访问，6.0 至 10 走存储写入），未授权期间日志暂存私有目录，授权后自动切换外部目录。
- 崩溃快照、Lua 报错快照、错误页扫描沿用既有能力，成品包与主程序行为一致。

## 二十三、成品包权限被裁剪

现象：成品包打开后进入“管理所有文件”页面，开关呈灰色不可操作，脚本也无法使用存储。

原因：打包器改写清单时按项目内的权限声明做裁剪，未声明的权限统一替换成无效项。实测成品包 56 项权限中绝大多数都变成了无效项，所有文件访问权限因此丢失，系统设置里连开关都无法打开。

处置：

- 删除裁剪逻辑，成品包整体继承模板的完整权限清单，项目内的同名文件仍优先覆盖，但不再删减权限。
- 新增权限助手 `permissions` 模块与同名 Java 类：脚本一行 `permissions.ensure("storage","camera","microphone")` 即可按需申请，不必各项目自写授权流程；存储走所有文件访问页面，其余走系统弹窗。
- 启动页对成品包继续自动申请所有文件访问，与权限助手互补。

## 二十四、内置手册打不开与内容重构

现象：从菜单进入“Lua 参考手册”，页面显示无法打开，错误为 `ERR_ACCESS_DENIED`，地址指向私有目录 `files/luadoc/manual.html`。

原因：浏览器内核不允许页面直接加载应用私有目录下的 `file://` 地址，即使文件确实存在也会被拒绝。手册原本按私有目录路径加载，因此必然失败。

处置：

- 手册改从安装包内置资源读取（`file:///android_asset/luadoc/`），这条路径由系统放行，同时打开脚本读取开关与缩放设置。
- 重构手册结构：新增首页导航、快速开始、常用接口、打包与权限、常见问题、术语表六个页面，统一视觉主题并适配手机阅读；页面支持自动生成小目录、代码一键复制、首页卡片搜索。
- 保留上游 Lua 5.3 标准参考并套用同一套主题，补齐返回目录入口。
- 手册内容按本项目的实际能力编写，包含权限助手、日志目录、打包签名与安装排错的真实处理方式。

## 二十五、手册交互反馈不足

现象：点按目录按钮与页面条目时没有明显反馈，看不出是否点中，也没有快速切换页面的入口。

处置：

- 新增侧滑抽屉导航：顶栏目录按钮打开抽屉，七个页面列表常驻，当前页高亮，遮罩点击关闭，滑入滑出带动画。
- 目录条目改为整行可点区域，按压底色变化并显示左侧色条；滚动时按当前章节自动高亮。
- 首页卡片按压缩放并显示阴影与描边变化；顶栏按钮按下缩放并变色。
- 页面切换增加轻微上浮淡入动效，代码复制按钮反馈保留，整体加平滑滚动与统一按压态。
- 标准手册页保留悬浮目录入口，同样带按压反馈。


## 二十六、程序骨架改为应用清单

原结构：启动页之后直接进入编辑器，工程管理藏在编辑器菜单里，不符合以应用为中心的用法。

现任结构：

- 首页为应用列表：扫描外部目录 `LuaXPlus/project`，按修改时间排序，卡片显示图标、名称、版本、包名、体积与简介；支持搜索、新建、长按重命名与删除。
- 详情页四个页签：属性（可编辑并保存到 `init.lua`）、目录（面包屑浏览、新建文件与文件夹、点文件可编辑或运行）、权限（分组开关，保存后写入 `user_permission` 并置 `strict_permissions=true`）、日志（汇总主程序与同名成品日志）。
- 底部固定三个动作：运行、打包、编辑器；编辑器保留为独立入口，不再作为启动首页。
- 打包器读取项目的权限勾选：仅当项目置了 `strict_permissions` 时按勾选裁剪清单，并始终保留联网与存储四项，避免日志与基础功能失效。
