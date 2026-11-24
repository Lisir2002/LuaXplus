package com.mini.luaxplus.java;

import android.view.View;

public interface JavaScreen {
    View onCreateView(JavaHost host);

    void onCreate(JavaHost host);

    void onResume(JavaHost host);

    void onPause(JavaHost host);

    void onDestroy(JavaHost host);

    boolean onBackPressed(JavaHost host);
}
