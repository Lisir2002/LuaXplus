package com.example.bridge;

/** 供 Lua 通过反射调用的动态 Java 静态方法。 */
public final class BridgeApi {

    private BridgeApi() {
    }

    public static String ping(String value) {
        return "Java 静态方法收到：" + value;
    }
}
