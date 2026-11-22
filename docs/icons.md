# 全局图标规范

Mini-LuaXPLUS 的界面图标统一走 `luaxplus.icons`，页面和组件不再直接使用 `TextView` 字形充当图标。

## 资源链路

1. 源稿：`design/icons/ic_luax_*.svg`，24×24 网格，2px 黑色描边。
2. 生成：`python3 tools/icons/build_icons.py` 同时生成 SVG 和 Android `VectorDrawable`。
3. 运行：`app/src/main/assets/lua/luaxplus/icons.lua` 负责加载、着色和尺寸约束。

Android 运行时不能直接渲染 SVG，因此 SVG 是设计源稿，APK 内使用等价的 `VectorDrawable`。路径数据完全一致，不会产生二次绘制偏差。

## 颜色与主题

- 图标本体以 `#1C2B3A` 深墨色描边，保持黑白灰主调。
- 彩色只出现在图标徽章的底色和选中态上，由页面传入 `accent`、`accentWash`、`warmWash` 等令牌。
- `icons.contrast(background)` 会按背景亮度选择深墨或白色前景，深色主题、浅色纸面和彩色底都能保持对比度。
- 页面不要写死图标颜色；优先传 `color`，或让 `icons.chip` / `icons.button` 按底色自动选择。

## 常用接口

```lua
local icons = require "luaxplus.icons"

icons.view("menu", { size = 22, color = INK })
icons.chip("manual", { size = 32, background = ACCENT_WASH, color = ACCENT_DEEP })
icons.button("add", "新建", { background = ACCENT_WASH, stroke = ACCENT_LINE, color = ACCENT_DEEP })
```

`view` 返回固定尺寸的 `ImageView`；`chip` 返回带圆角底色的图标徽章；`button` 返回图标加文字的横向按钮。找不到资源时会退回同名字形，避免裁剪包直接崩溃。

## 覆盖范围

首页、编辑器、项目页、设置、关于、示例列表、Java 浏览器、手册 Activity、LuaX-UI 组件库和组件示例都使用同一套图标。新增图标时先加 SVG 源稿和生成脚本定义，再在 `icons.lua` 注册名称。

预览板：`docs/icons-preview.png`。
