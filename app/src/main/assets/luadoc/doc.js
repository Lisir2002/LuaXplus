/* 手册通用交互：桌面侧栏、移动抽屉、目录高亮、阅读进度、代码复制、全局搜索 */
(function () {
  var PAGES = [
    { file: "contents.html", mark: "始", title: "手册首页", group: "开始", desc: "三条上手路径与全部章节入口", keywords: "首页 目录 开始 索引" },
    { file: "start.html", mark: "启", title: "快速开始", group: "开始", desc: "新建工程、写脚本、运行第一个界面", keywords: "新建 工程 运行 目录 main.lua 入口 五分钟" },
    { file: "api.html", mark: "接", title: "常用接口", group: "开发", desc: "import、luajava、界面、事件、文件、网络、线程", keywords: "import luajava 布局 控件 事件 对话框 文件 网络 线程 权限 日志" },
    { file: "uikit.html", mark: "UI", title: "LuaX-UI 组件库", group: "开发", desc: "iOS 风格组件、快捷页面、表单、动画与完整示例", keywords: "ui 组件 按钮 表单 弹窗 动画 主题 示例 页面 show form animate" },
    { file: "pack.html", mark: "包", title: "打包与权限", group: "发布", desc: "打包流程、签名、安装、权限清单与成品日志", keywords: "打包 签名 安装 权限 成品 日志 apk 发布" },
    { file: "faq.html", mark: "问", title: "常见问题", group: "发布", desc: "模块找不到、界面错误、安装被拒、日志排查", keywords: "报错 模块 找不到 闪退 安装 日志 排查 权限" },
    { file: "manual.html", mark: "典", title: "Lua 语言参考", group: "参考", desc: "Lua 5.3 语法、元表、协程、标准库与 C API", keywords: "lua 语法 元表 协程 标准库 string table math io os" },
    { file: "glossary.html", mark: "术", title: "术语表", group: "参考", desc: "工程目录、app_lua、dex、快照等名词解释", keywords: "术语 名词 目录 app_lua dex 快照 运行时 铺设" }
  ];

  function ready(fn) {
    if (document.readyState === "complete" || document.readyState === "interactive") {
      setTimeout(fn, 0);
    } else {
      document.addEventListener("DOMContentLoaded", fn, false);
    }
  }

  function currentFile() {
    var path = location.pathname || "";
    var name = path.substring(path.lastIndexOf("/") + 1);
    return name || "contents.html";
  }

  function pageOf(file) {
    for (var i = 0; i < PAGES.length; i++) {
      if (PAGES[i].file === file) { return PAGES[i]; }
    }
    return null;
  }

  function esc(text) {
    return String(text == null ? "" : text)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function norm(text) {
    return String(text == null ? "" : text).toLowerCase().replace(/\s+/g, " ");
  }

  /* ---------- 顶栏与旧页面兼容 ---------- */
  function buildTopbar() {
    var bar = document.querySelector(".topbar");
    if (!bar) {
      var body = document.body;
      var wrap = document.createElement("div");
      wrap.className = "wrap manual-content";
      while (body.firstChild) { wrap.appendChild(body.firstChild); }
      body.appendChild(wrap);
      body.classList.add("manual-page");
      bar = document.createElement("div");
      bar.className = "topbar";
      bar.innerHTML =
        '<button class="home menu-btn" type="button" aria-label="打开目录">☰</button>' +
        '<span class="title">Lua 语言参考</span>';
      body.insertBefore(bar, wrap);
    }
    if (!bar.querySelector(".search-btn")) {
      var button = document.createElement("button");
      button.className = "search-btn";
      button.type = "button";
      button.setAttribute("aria-label", "搜索手册章节");
      button.innerHTML = "⌕ <span>搜索</span>";
      var sub = bar.querySelector(".sub");
      if (sub) { bar.insertBefore(button, sub); } else { bar.appendChild(button); }
    }
  }

  /* ---------- 侧栏 ---------- */
  function buildDrawer() {
    var current = currentFile();
    var groups = [];
    var inner = "";
    for (var i = 0; i < PAGES.length; i++) {
      var p = PAGES[i];
      if (groups.indexOf(p.group) < 0) {
        groups.push(p.group);
        inner += '<div class="group">' + esc(p.group) + "</div>";
      }
      var active = p.file === current ? " current" : "";
      inner += '<a class="nav-item' + active + '" href="' + p.file + '" data-title="' +
        esc(norm(p.title + " " + p.desc + " " + p.keywords)) + '">' +
        "<em>" + esc(p.mark) + "</em><span>" + esc(p.title) + "</span></a>";
    }

    var drawer = document.createElement("div");
    drawer.className = "drawer";
    drawer.innerHTML =
      '<div class="mask"></div>' +
      '<aside class="panel" aria-label="手册章节">' +
        '<div class="brand"><span class="logo">ML</span>' +
          '<div><b>Mini-LuaXPLUS</b><span>内置使用手册 · 离线可用</span></div></div>' +
        '<label class="nav-search"><span>⌕</span>' +
          '<input id="side-search" type="search" placeholder="筛选章节" aria-label="筛选章节"></label>' +
        "<nav>" + inner + "</nav>" +
        '<div class="side-foot">当前页会在目录中高亮。<br>按 / 可快速搜索全部章节。</div>' +
      "</aside>";
    document.body.appendChild(drawer);

    var mask = drawer.querySelector(".mask");
    mask.onclick = function () { closeDrawer(drawer); };

    var buttons = document.querySelectorAll(".menu-btn");
    for (var b = 0; b < buttons.length; b++) {
      buttons[b].onclick = function () { openDrawer(drawer); };
    }

    var input = drawer.querySelector("#side-search");
    var links = drawer.querySelectorAll("nav a");
    input.oninput = function () {
      var word = norm(input.value).trim();
      for (var j = 0; j < links.length; j++) {
        var hit = !word || (links[j].getAttribute("data-title") || "").indexOf(word) >= 0;
        links[j].style.display = hit ? "flex" : "none";
      }
      var heads = drawer.querySelectorAll(".group");
      for (var k = 0; k < heads.length; k++) {
        var node = heads[k].nextElementSibling;
        var any = false;
        while (node && !node.classList.contains("group")) {
          if (node.style.display !== "none") { any = true; }
          node = node.nextElementSibling;
        }
        heads[k].style.display = any ? "block" : "none";
      }
    };

    drawer.addEventListener("keydown", function (event) {
      if (event.key === "Escape") { closeDrawer(drawer); }
    });
    return drawer;
  }

  function openDrawer(drawer) {
    if (window.innerWidth >= 1080) { return; }
    drawer.className = "drawer open";
    document.body.style.overflow = "hidden";
    var input = drawer.querySelector("#side-search");
    if (input) { setTimeout(function () { input.focus(); }, 120); }
  }

  function closeDrawer(drawer) {
    drawer.className = "drawer";
    document.body.style.overflow = "";
  }

  /* ---------- 面包屑 ---------- */
  function buildBreadcrumb() {
    var current = currentFile();
    if (current === "contents.html") { return; }
    var page = pageOf(current);
    var holder = document.querySelector(".manual-content") || document.querySelector(".wrap");
    if (!holder || !page || holder.querySelector(".crumbs")) { return; }
    var crumbs = document.createElement("div");
    crumbs.className = "crumbs";
    crumbs.innerHTML = '<a href="contents.html">手册</a><i>/</i><span>' + esc(page.title) + "</span>";
    holder.insertBefore(crumbs, holder.firstChild);
  }

  /* ---------- 本页目录 ---------- */
  function buildToc() {
    if (currentFile() === "contents.html") { return; }
    var manual = document.body.classList.contains("manual-page");
    var holder = document.getElementById("auto-toc");
    if (!holder) {
      var host = document.querySelector(".manual-content") || document.querySelector(".wrap");
      if (!host) { return; }
      holder = document.createElement("div");
      holder.id = "auto-toc";
      holder.className = "tocbox";
      if (manual) {
        var crumbs = host.querySelector(".crumbs");
        host.insertBefore(holder, crumbs ? crumbs.nextSibling : host.firstChild);
      } else {
        var firstHead = host.querySelector("h2") || host.querySelector("h3");
        if (firstHead && firstHead.parentNode === host) {
          host.insertBefore(holder, firstHead);
        } else {
          host.appendChild(holder);
        }
      }
    }
    var heads = document.querySelectorAll(manual ? "h1" : "h2, h3");
    if (!heads.length) { holder.style.display = "none"; return; }

    var details = document.createElement("details");
    details.className = "tocbox";
    details.id = "auto-toc";
    details.open = !manual && window.innerWidth >= 760 && heads.length <= 12;
    details.innerHTML = "<summary>本页目录</summary>";
    var list = document.createElement("ul");
    for (var i = 0; i < heads.length; i++) {
      var head = heads[i];
      if (!head.id) { head.id = "sec-" + i; }
      var li = document.createElement("li");
      if (manual && head.tagName.toLowerCase() === "h3") { li.className = "lv3"; }
      var link = document.createElement("a");
      link.href = "#" + head.id;
      link.textContent = (head.textContent || "").replace(/\s+/g, " ").trim();
      li.appendChild(link);
      list.appendChild(li);
    }
    details.appendChild(list);
    holder.parentNode.replaceChild(details, holder);
    highlightOnScroll(details);
  }

  function highlightOnScroll(holder) {
    var links = holder.querySelectorAll("a");
    if (!links.length) { return; }
    var ticking = false;
    function refresh() {
      ticking = false;
      var targets = [];
      for (var i = 0; i < links.length; i++) {
        var target = document.getElementById(links[i].getAttribute("href").substring(1));
        if (target) { targets.push({ link: links[i], el: target }); }
      }
      var index = 0;
      for (var j = 0; j < targets.length; j++) {
        if (targets[j].el.getBoundingClientRect().top < 130) { index = j; }
      }
      for (var k = 0; k < targets.length; k++) {
        targets[k].link.className = (k === index) ? "current" : "";
      }
    }
    window.addEventListener("scroll", function () {
      if (!ticking) { ticking = true; setTimeout(refresh, 120); }
    }, false);
    refresh();
  }

  /* ---------- 代码块 ---------- */
  function detectLang(pre) {
    var cls = pre.className || "";
    var found = cls.match(/language-([a-z0-9+#]+)/i);
    if (found) { return found[1].toUpperCase(); }
    var text = pre.innerText || pre.textContent || "";
    if (/^\s*(\$|adb |\.\/gradlew|cd |ls |mkdir |apksigner)/m.test(text)) { return "SHELL"; }
    if (/^\s*[\[{]/m.test(text) && /"\s*:/m.test(text)) { return "JSON"; }
    if (/<[a-z][\s\S]*>/i.test(text) && !/local |function |require |import "/.test(text)) { return "HTML"; }
    return "LUA";
  }

  function copyButtons() {
    var pres = document.getElementsByTagName("pre");
    for (var i = 0; i < pres.length; i++) {
      (function (pre) {
        if (pre.querySelector(".copy")) { return; }
        var raw = pre.innerText || pre.textContent || "";
        var lang = document.createElement("span");
        lang.className = "code-lang";
        lang.textContent = detectLang(pre);
        var button = document.createElement("button");
        button.className = "copy";
        button.type = "button";
        button.innerHTML = "复制";
        button.onclick = function () {
          try {
            var area = document.createElement("textarea");
            area.value = raw;
            area.style.position = "fixed";
            area.style.opacity = "0";
            document.body.appendChild(area);
            area.select();
            document.execCommand("copy");
            document.body.removeChild(area);
            button.innerHTML = "已复制";
            setTimeout(function () { button.innerHTML = "复制"; }, 1500);
          } catch (error) {
            button.innerHTML = "请长按复制";
          }
        };
        pre.appendChild(lang);
        pre.appendChild(button);
      })(pres[i]);
    }
  }

  /* ---------- 首页筛选 ---------- */
  function filterHome() {
    var input = document.getElementById("doc-search");
    if (!input) { return; }
    var cards = document.querySelectorAll(".grid .card");
    var chips = document.querySelectorAll(".task-chip");
    var empty = document.getElementById("search-empty");
    var count = document.getElementById("search-count");
    var clear = document.getElementById("search-clear");

    for (var i = 0; i < cards.length; i++) {
      cards[i].setAttribute("data-text", norm(cards[i].innerText + " " + (cards[i].getAttribute("data-keywords") || "")));
    }

    function refresh() {
      var word = norm(input.value).trim();
      var shown = 0;
      for (var i = 0; i < cards.length; i++) {
        var hit = !word || (cards[i].getAttribute("data-text") || "").indexOf(word) >= 0;
        cards[i].style.display = hit ? "" : "none";
        if (hit) { shown++; }
      }
      for (var j = 0; j < chips.length; j++) {
        var chipHit = !word || norm(chips[j].innerText).indexOf(word) >= 0;
        chips[j].style.display = chipHit ? "" : "none";
      }
      if (empty) { empty.className = (shown === 0 && word) ? "empty show" : "empty"; }
      if (count) {
        count.textContent = word ? "找到 " + shown + " 个章节" : "共 " + cards.length + " 个章节";
      }
      if (clear) { clear.className = word ? "clear show" : "clear"; }
    }

    input.oninput = refresh;
    if (clear) {
      clear.onclick = function () {
        input.value = "";
        refresh();
        input.focus();
      };
    }
    refresh();
  }

  /* ---------- 全局搜索 ---------- */
  function buildGlobalSearch() {
    var button = document.querySelector(".topbar .search-btn");
    if (!button) { return; }
    var modal = document.createElement("div");
    modal.className = "search-modal";
    modal.innerHTML =
      '<div class="search-sheet" role="dialog" aria-label="搜索手册">' +
        '<div class="head"><input id="global-search" type="search" placeholder="搜索章节、组件、报错关键词" aria-label="搜索手册">' +
          '<button class="close" type="button">关闭</button></div>' +
        '<div class="hits" id="global-hits"></div>' +
      "</div>";
    document.body.appendChild(modal);

    var input = modal.querySelector("#global-search");
    var hits = modal.querySelector("#global-hits");

    function render() {
      var word = norm(input.value).trim();
      var result = "";
      var total = 0;
      for (var i = 0; i < PAGES.length; i++) {
        var p = PAGES[i];
        if (word && norm(p.title + " " + p.desc + " " + p.keywords).indexOf(word) < 0) { continue; }
        total++;
        result += '<a class="hit" href="' + p.file + '"><b>' + esc(p.title) + "</b><small>" +
          esc(p.desc) + "</small></a>";
      }
      hits.innerHTML = total ? result : '<div class="none">没有匹配的章节，换个词试试</div>';
    }

    function open() {
      modal.className = "search-modal open";
      input.value = "";
      render();
      setTimeout(function () { input.focus(); }, 80);
    }

    function close() {
      modal.className = "search-modal";
      button.focus();
    }

    button.onclick = open;
    modal.querySelector(".close").onclick = close;
    modal.onclick = function (event) {
      if (event.target === modal) { close(); }
    };
    input.oninput = render;
    input.onkeydown = function (event) {
      if (event.key === "Enter") {
        var first = hits.querySelector(".hit");
        if (first) { location.href = first.getAttribute("href"); }
      }
    };
    document.addEventListener("keydown", function (event) {
      var tag = (event.target.tagName || "").toLowerCase();
      if (event.key === "/" && tag !== "input" && tag !== "textarea") {
        event.preventDefault();
        open();
      }
      if (event.key === "Escape" && modal.classList.contains("open")) { close(); }
    });
  }

  /* ---------- 上一页 / 下一页 ---------- */
  function buildPageNav() {
    var current = currentFile();
    var index = -1;
    for (var i = 0; i < PAGES.length; i++) {
      if (PAGES[i].file === current) { index = i; }
    }
    if (index < 0 || current === "contents.html") { return; }
    var host = document.querySelector(".manual-content") || document.querySelector(".wrap");
    if (!host || host.querySelector(".page-nav")) { return; }

    var prev = index > 0 ? PAGES[index - 1] : null;
    var next = index < PAGES.length - 1 ? PAGES[index + 1] : null;
    var nav = document.createElement("div");
    nav.className = "page-nav";
    nav.innerHTML =
      (prev ? '<a href="' + prev.file + '"><small>上一页</small><b>← ' + esc(prev.title) + "</b></a>" :
        '<a class="placeholder"></a>') +
      (next ? '<a class="next" href="' + next.file + '"><small>下一页</small><b>' + esc(next.title) + " →</b></a>" :
        '<a class="placeholder"></a>');
    host.appendChild(nav);
  }

  /* ---------- 进度与返回顶部 ---------- */
  function buildScrollTools() {
    var bar = document.createElement("div");
    bar.className = "reading";
    document.body.appendChild(bar);

    var top = document.createElement("button");
    top.className = "backtop";
    top.type = "button";
    top.setAttribute("aria-label", "返回顶部");
    top.innerHTML = "↑";
    top.onclick = function () {
      try { window.scrollTo({ top: 0, behavior: "smooth" }); }
      catch (error) { window.scrollTo(0, 0); }
    };
    document.body.appendChild(top);

    var ticking = false;
    function refresh() {
      ticking = false;
      var height = document.documentElement.scrollHeight - window.innerHeight;
      bar.style.width = (height > 0 ? Math.min(100, window.pageYOffset / height * 100) : 0) + "%";
      top.className = window.pageYOffset > 420 ? "backtop show" : "backtop";
    }
    window.addEventListener("scroll", function () {
      if (!ticking) { ticking = true; setTimeout(refresh, 60); }
    }, false);
    refresh();
  }

  function pressFeedback() {
    var targets = document.querySelectorAll("a, button");
    for (var i = 0; i < targets.length; i++) {
      targets[i].addEventListener("touchstart", function () {
        this.className = (this.className || "") + " pressed";
      }, false);
      targets[i].addEventListener("touchend", function () {
        this.className = (this.className || "").replace(/\s*pressed/g, "");
      }, false);
    }
  }

  ready(function () {
    buildTopbar();
    buildDrawer();
    buildBreadcrumb();
    buildToc();
    copyButtons();
    filterHome();
    buildGlobalSearch();
    buildPageNav();
    buildScrollTools();
    pressFeedback();
    document.body.className = (document.body.className || "") + " page-enter";
  });
})();
