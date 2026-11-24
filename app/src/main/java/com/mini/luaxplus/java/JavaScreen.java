package com.mini.luaxplus.java;

import android.view.View;

/**
 * Java 页面的宿主接口。
 *
 * 页面类不直接继承 Activity，而是把根 View 和生命周期交给已注册的 JavaHostActivity。
 * 这样运行期从 DEX 加载的类也能参与页面栈，不需要修改 AndroidManifest。
 */
public interface JavaScreen {

    View onCreateView(JavaHost host);

    default void onCreate(JavaHost host) {
    }

    default void onResume(JavaHost host) {
    }

    default void onPause(JavaHost host) {
    }

    default void onDestroy(JavaHost host) {
    }

    default boolean onBackPressed(JavaHost host) {
        return false;
    }
}
