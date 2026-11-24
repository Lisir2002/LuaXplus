package javax.lang.model;

/**
 * ECJ 批量编译器启动时会探测 JDK 12 的 SourceVersion，用来判断是否启用 jrt 类路径。
 * Android 没有 java.compiler 模块，也没有这个类，这里补齐最小枚举让探测走 Android
 * 对应的 Java 8 分支，避免 FileSystem 初始化直接失败。
 *
 * 只列 Java 8 及更早的版本：ECJ 探测 RELEASE_12 时会抛出 IllegalArgumentException，
 * 从而把 isJRE12Plus 保持为 false，不会去使用 Android 上不存在的 jrt 文件系统。
 */
public enum SourceVersion {
    RELEASE_0,
    RELEASE_1,
    RELEASE_2,
    RELEASE_3,
    RELEASE_4,
    RELEASE_5,
    RELEASE_6,
    RELEASE_7,
    RELEASE_8
}
