# 第三方组件与许可

本项目包含或按需分发以下第三方组件。它们的使用、复制和再分发分别适用下列许可证；本项目只对自身代码采用 MIT 许可。

| 组件 | 版本 | 上游来源 | 许可证 | 本项目中的形态 |
| --- | --- | --- | --- | --- |
| Eclipse Compiler for Java（ECJ） | 3.26.0 | Eclipse JDT，Maven Central `org.eclipse.jdt:ecj:3.26.0` | Eclipse Public License 2.0（EPL-2.0） | 由官方 JAR 转换为 Android DEX，按需放入编译器插件 |
| D8 / R8 | 3.3.20 | Google R8，Google Maven `com.android.tools:r8:3.3.20` | 3-Clause BSD License | 由官方 JAR 转换为 Android DEX，按需放入编译器插件 |
| Android SDK `android.jar` | Platform 34 | Android SDK Platform 34 | Android SDK License Agreement | 仅作为编译 classpath，不从本仓库分发；需在构建机通过 SDK Manager 安装 |

## 说明

- ECJ 与 D8 的 Java 包不修改编译器算法，只做运行形态转换（JVM 字节码转 Android DEX）和运行时资源整理。
- 编译器插件中的 `compiler.dex` 是上述官方构件的转换结果；插件同时附带对应许可证文本。
- `android.jar` 受 Android SDK 许可约束，不纳入 Git 仓库，也不随源码仓库分发。构建插件前需自行安装 Android SDK Platform 34。
- 各许可证全文位于 `licenses/`；编译器插件安装后的许可证位于 `resources/licenses/`。

## 许可证全文

- Eclipse Public License 2.0：`licenses/eclipse-public-license-2.0.txt`
- R8 / D8 及第三方许可证清单：`licenses/r8-d8-license.txt`

## 上游链接

- ECJ：https://github.com/eclipse-jdt/eclipse.jdt.core
- ECJ Maven 构件：https://repo1.maven.org/maven2/org/eclipse/jdt/ecj/3.26.0/
- R8 / D8：https://r8.googlesource.com/r8
- Android SDK：https://developer.android.com/studio
