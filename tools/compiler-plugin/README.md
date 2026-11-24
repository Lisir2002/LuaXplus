# Java 编译器插件

插件市场下载的 `compiler-plugin-*.zip` 由本目录的官方构件整理而成，主 APK 不再内置 ECJ、D8 或 `android.jar`。

## 目录

- `source/libs/ecj-3.26.0.jar`：Eclipse JDT 官方构件
- `source/libs/d8-3.3.20.jar`：Google R8/D8 官方构件
- `source/android.jar`：构建机 Android SDK Platform 34 的 `android.jar`（本地输入，不纳入 Git）
- `compiler.dex`：由 ECJ 与 D8 转换的 Android DEX（构建产物，不纳入 Git）
- `android.jar`：准备打进插件包的副本（构建产物，不纳入 Git）
- `resources/`：ECJ/D8 运行时资源与许可证
- `version.txt`：插件版本号

## 插件包内容

最终 ZIP 固定包含：

- `compiler.dex`
- `android.jar`
- `version.txt`
- `resources/`，其中包含 `licenses/ECLIPSE-PUBLIC-LICENSE-2.0.txt`、`licenses/R8-D8-LICENSE.txt` 和 `NOTICE.txt`

## 构建约束

- 只使用官方构件，不修改编译器算法。
- `android.jar` 受 Android SDK 许可约束，必须由构建机自行安装，不提交到仓库。
- `compiler.dex` 不提交到仓库。
- 插件市场公开下载包 `dist/compiler-plugin-1.2.zip` 是例外，必须提交到仓库供 GitHub 直链下载；其他 `dist/*` 构建产物不提交。
- 发布前重新计算 ZIP 的 SHA-256，并同步更新 `app/src/main/assets/pluginmarket.lua` 中的下载地址、哈希和大小。
- 版本号和许可证说明必须与包内 `version.txt`、`resources/NOTICE.txt` 保持一致。
