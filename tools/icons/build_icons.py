#!/usr/bin/env python3
"""生成 Mini-LuaXPLUS 的全局图标源稿。

图标以 24×24 网格、黑色描边为源稿，Android 端同步生成 VectorDrawable。
运行期只通过 setColorFilter 着色，因此同一份图标可适配浅色、深色和彩色背景。
"""

from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
SVG_DIR = ROOT / "design" / "icons"
DRAWABLE_DIR = ROOT / "app" / "src" / "main" / "res" / "drawable"

# d 为路径；fill=True 时使用填充，否则使用统一描边。
ICONS = {
    "menu": [
        {"d": "M3.5 7h17"},
        {"d": "M3.5 12h17"},
        {"d": "M3.5 17h10.5"},
    ],
    "close": [
        {"d": "M6 6l12 12"},
        {"d": "M18 6l-12 12"},
    ],
    "add": [
        {"d": "M12 4.8v14.4"},
        {"d": "M4.8 12h14.4"},
    ],
    "edit": [
        {"d": "M4.5 19.5l1.2-4.2L15.8 4.2a2.4 2.4 0 0 1 3.4 3.4L8.7 18.3z"},
        {"d": "M13.5 6.5l3.9 3.9"},
    ],
    "manual": [
        {"d": "M4 6.6c2.7-1.5 5.3-1 8 .5 2.7-1.5 5.3-2 8-.5v12c-2.7-1.5-5.3-1-8 .5-2.7-1.5-5.3-2-8-.5z"},
        {"d": "M12 7v12"},
    ],
    "code": [
        {"d": "M9.3 7L4.5 12l4.8 5"},
        {"d": "M14.7 7l4.8 5-4.8 5"},
        {"d": "M13.2 5.5l-2.4 13"},
    ],
    "info": [
        {"d": "M12 4.2a7.8 7.8 0 1 0 0 15.6a7.8 7.8 0 1 0 0-15.6"},
        {"d": "M12 11v5.2"},
        {"d": "M12 8.4m-1 0a1 1 0 1 0 2 0a1 1 0 1 0-2 0", "fill": True},
    ],
    "settings": [
        {"d": "M12 9.1a2.9 2.9 0 1 0 0 5.8a2.9 2.9 0 1 0 0-5.8"},
        {"d": "M12 3.5v2"},
        {"d": "M12 18.5v2"},
        {"d": "M3.5 12h2"},
        {"d": "M18.5 12h2"},
        {"d": "M5.7 5.7l1.4 1.4"},
        {"d": "M16.9 16.9l1.4 1.4"},
        {"d": "M18.3 5.7l-1.4 1.4"},
        {"d": "M7.1 16.9l-1.4 1.4"},
    ],
    "chevron-right": [
        {"d": "M9 5.8l6.2 6.2-6.2 6.2"},
    ],
    "chevron-left": [
        {"d": "M15 5.8L8.8 12l6.2 6.2"},
    ],
    "undo": [
        {"d": "M9 7L5 11l4 4"},
        {"d": "M5.5 11h7a5 5 0 0 1 0 10H8"},
    ],
    "redo": [
        {"d": "M15 7l4 4-4 4"},
        {"d": "M18.5 11h-7a5 5 0 0 0 0 10H16"},
    ],
    "more": [
        {"d": "M5 12m-1.3 0a1.3 1.3 0 1 0 2.6 0a1.3 1.3 0 1 0-2.6 0", "fill": True},
        {"d": "M12 12m-1.3 0a1.3 1.3 0 1 0 2.6 0a1.3 1.3 0 1 0-2.6 0", "fill": True},
        {"d": "M19 12m-1.3 0a1.3 1.3 0 1 0 2.6 0a1.3 1.3 0 1 0-2.6 0", "fill": True},
    ],
    "search": [
        {"d": "M11 4.8a6.2 6.2 0 1 0 0 12.4a6.2 6.2 0 1 0 0-12.4"},
        {"d": "M15.4 15.4l4 4"},
    ],
    "example": [
        {"d": "M12 3.8l1.7 5.5L19 11l-5.3 1.7L12 18.3l-1.7-5.6L5 11l5.3-1.7z"},
        {"d": "M18.4 4.4m-.8 0a.8 .8 0 1 0 1.6 0a.8 .8 0 1 0-1.6 0", "fill": True},
    ],
    "log": [
        {"d": "M6 3.8h7.8l4 4v12.4h-12z"},
        {"d": "M8.5 9.8h6"},
        {"d": "M8.5 13h6"},
        {"d": "M8.5 16.2h4"},
    ],
    "run": [
        {"d": "M7.5 5.3l11 6.7-11 6.7z", "fill": True},
    ],
    "package": [
        {"d": "M4 8.5L12 4.5l8 4v8L12 20l-8-4z"},
        {"d": "M4 8.5L12 12.5l8-4"},
        {"d": "M12 12.5v8"},
    ],
    "shield": [
        {"d": "M12 3.5l7 3v5.2c0 4-2.9 6.6-7 7.8-4.1-1.2-7-3.8-7-7.8V6.5z"},
        {"d": "M12 9.5a1.8 1.8 0 1 0 0 3.6a1.8 1.8 0 1 0 0-3.6"},
        {"d": "M12 13.1v3"},
    ],
    "home": [
        {"d": "M4 11.5L12 4.5l8 7v9h-5.5v-6h-5v6H4z"},
    ],
    "mail": [
        {"d": "M4.5 6.5h15v11h-15z"},
        {"d": "M5 7l7 6 7-6"},
    ],
    "check": [
        {"d": "M5 12l4.5 4.5L19 7"},
    ],
    "folder": [
        {"d": "M3.5 6.5h6l2 2h9v10.5h-17z"},
    ],
    "save": [
        {"d": "M5 4.5h12l2.5 2.5v13h-14z"},
        {"d": "M8 4.5v5h8v-5"},
        {"d": "M8 14h8v5H8z"},
    ],
    "wrap": [
        {"d": "M4 7h13a3 3 0 0 1 0 6H8"},
        {"d": "M8 10l-3 3 3 3"},
        {"d": "M4 17h6"},
    ],
    "empty": [
        {"d": "M4 8h16v11h-16z"},
        {"d": "M4 8l3-4h10l3 4"},
        {"d": "M8 12h8"},
    ],
    "radio": [
        {"d": "M12 4.5a7.5 7.5 0 1 0 0 15a7.5 7.5 0 1 0 0-15"},
    ],
    "radio-checked": [
        {"d": "M12 4.5a7.5 7.5 0 1 0 0 15a7.5 7.5 0 1 0 0-15"},
        {"d": "M12 8.5a3.5 3.5 0 1 0 0 7a3.5 3.5 0 1 0 0-7", "fill": True},
    ],
    "file": [
        {"d": "M6 3.5h8l4 4v13H6z"},
        {"d": "M14 3.5v4h4"},
        {"d": "M9 12h6"},
        {"d": "M9 15.5h4"},
    ],
}

SVG_HEAD = (
    '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" '
    'viewBox="0 0 24 24" fill="none" stroke="#1C2B3A" stroke-width="2" '
    'stroke-linecap="round" stroke-linejoin="round">'
)
ANDROID_NS = "http://schemas.android.com/apk/res/android"


def element_for_svg(item):
    d = item["d"]
    if item.get("fill"):
        return f'  <path d="{d}" fill="#1C2B3A" stroke="none"/>'
    return f'  <path d="{d}"/>'


def write_svg(name, items):
    content = "\n".join(
        [SVG_HEAD]
        + [element_for_svg(item) for item in items]
        + ["</svg>", ""]
    )
    (SVG_DIR / f"ic_luax_{name.replace(chr(45), chr(95))}.svg").write_text(content, encoding="utf-8")


def write_vector(name, items):
    ET.register_namespace("android", ANDROID_NS)
    root = ET.Element(
        "vector",
        {
            f"{{{ANDROID_NS}}}width": "24dp",
            f"{{{ANDROID_NS}}}height": "24dp",
            f"{{{ANDROID_NS}}}viewportWidth": "24",
            f"{{{ANDROID_NS}}}viewportHeight": "24",
        },
    )
    for item in items:
        attrs = {f"{{{ANDROID_NS}}}pathData": item["d"]}
        if item.get("fill"):
            attrs[f"{{{ANDROID_NS}}}fillColor"] = "#FF1C2B3A"
        else:
            attrs[f"{{{ANDROID_NS}}}fillColor"] = "#00000000"
            attrs[f"{{{ANDROID_NS}}}strokeColor"] = "#FF1C2B3A"
            attrs[f"{{{ANDROID_NS}}}strokeWidth"] = "2"
            attrs[f"{{{ANDROID_NS}}}strokeLineCap"] = "round"
            attrs[f"{{{ANDROID_NS}}}strokeLineJoin"] = "round"
        ET.SubElement(root, "path", attrs)
    tree = ET.ElementTree(root)
    ET.indent(tree, space="  ")
    tree.write(
        DRAWABLE_DIR / f"ic_luax_{name.replace('-', '_')}.xml",
        encoding="utf-8",
        xml_declaration=True,
    )


def main():
    SVG_DIR.mkdir(parents=True, exist_ok=True)
    DRAWABLE_DIR.mkdir(parents=True, exist_ok=True)
    for name, items in ICONS.items():
        write_svg(name, items)
        write_vector(name, items)
    print(f"generated {len(ICONS)} icons")


if __name__ == "__main__":
    main()
