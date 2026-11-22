/* 手册通用交互：侧边导航、目录高亮、代码复制、首页搜索 */
(function () {
  var PAGES = [
    { file: "contents.html", mark: "始", title: "手册首页" },
    { file: "start.html", mark: "启", title: "快速开始" },
    { file: "api.html", mark: "接", title: "常用接口" },
    { file: "uikit.html", mark: "UI", title: "LuaX-UI 组件库" },
    { file: "pack.html", mark: "包", title: "打包与权限" },
    { file: "faq.html", mark: "问", title: "常见问题" },
    { file: "manual.html", mark: "典", title: "Lua 语言参考" },
    { file: "glossary.html", mark: "术", title: "术语表" }
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

  function buildDrawer() {
    var drawer = document.createElement("div");
    drawer.className = "drawer";
    var inner = "";
    for (var i = 0; i < PAGES.length; i++) {
      var active = PAGES[i].file === currentFile() ? " current" : "";
      inner += '<a class="nav-item' + active + '" href="' + PAGES[i].file + '">' +
        "<em>" + PAGES[i].mark + "</em><span>" + PAGES[i].title + "</span></a>";
    }
    drawer.innerHTML =
      '<div class="mask"></div>' +
      '<aside class="panel">' +
        '<div class="brand"><em style="width:30px;height:30px;display:grid;place-items:center;border-radius:10px;background:#1c2b3a;color:#f7f1e6;font-style:normal;font-size:13px">M</em>' +
          "<div><b>Mini-LuaXPLUS</b><br><span>内置使用手册</span></div></div>" +
        '<nav>' + inner + "</nav>" +
        '<div style="padding:16px 6px;color:#5f6f7c;font-size:12px">点击条目直接跳转，当前页已高亮</div>' +
      "</aside>";
    document.body.appendChild(drawer);

    var mask = drawer.getElementsByClassName("mask")[0];
    mask.onclick = function () { closeDrawer(drawer); };

    var buttons = document.getElementsByClassName("menu-btn");
    for (var b = 0; b < buttons.length; b++) {
      buttons[b].onclick = function () { openDrawer(drawer); };
    }
    return drawer;
  }

  function openDrawer(drawer) {
    drawer.className = "drawer open";
  }

  function closeDrawer(drawer) {
    drawer.className = "drawer";
  }

  function buildToc() {
    var holder = document.getElementById("auto-toc");
    if (!holder) { return; }
    var heads = document.getElementsByTagName("h2");
    if (!heads.length) { holder.style.display = "none"; return; }
    var list = document.createElement("ul");
    for (var i = 0; i < heads.length; i++) {
      var anchor = "sec-" + i;
      heads[i].id = anchor;
      var li = document.createElement("li");
      var link = document.createElement("a");
      link.href = "#" + anchor;
      link.innerHTML = heads[i].innerHTML.replace(/<[^>]+>/g, "");
      li.appendChild(link);
      list.appendChild(li);
    }
    holder.innerHTML = "<strong>本页目录</strong>";
    holder.appendChild(list);
    highlightOnScroll(holder);
  }

  function highlightOnScroll(holder) {
    var links = holder.getElementsByTagName("a");
    if (!links.length) { return; }
    var ticking = false;
    function refresh() {
      ticking = false;
      var heads = document.getElementsByTagName("h2");
      var index = 0;
      for (var i = 0; i < heads.length; i++) {
        if (heads[i].getBoundingClientRect().top < 120) { index = i; }
      }
      for (var j = 0; j < links.length; j++) {
        links[j].className = (j === index) ? "current" : "";
      }
    }
    window.addEventListener("scroll", function () {
      if (!ticking) { ticking = true; setTimeout(refresh, 120); }
    }, false);
    refresh();
  }

  function copyButtons() {
    var pres = document.getElementsByTagName("pre");
    for (var i = 0; i < pres.length; i++) {
      (function (pre) {
        var button = document.createElement("button");
        button.className = "copy";
        button.type = "button";
        button.innerHTML = "复制";
        button.onclick = function () {
          var text = pre.innerText || pre.textContent || "";
          text = text.replace(/^\s*复制\s*/m, "").replace(/复制$/, "");
          try {
            var area = document.createElement("textarea");
            area.value = text;
            area.style.position = "fixed";
            area.style.opacity = "0";
            document.body.appendChild(area);
            area.select();
            document.execCommand("copy");
            document.body.removeChild(area);
            button.innerHTML = "已复制";
            setTimeout(function () { button.innerHTML = "复制"; }, 1600);
          } catch (error) {
            button.innerHTML = "请长按复制";
          }
        };
        pre.appendChild(button);
      })(pres[i]);
    }
  }

  function filterCards() {
    var input = document.getElementById("doc-search");
    if (!input) { return; }
    var cards = document.getElementsByClassName("card");
    input.oninput = function () {
      var word = input.value.trim().toLowerCase();
      for (var i = 0; i < cards.length; i++) {
        var text = (cards[i].innerText || cards[i].textContent || "").toLowerCase();
        cards[i].style.display = (!word || text.indexOf(word) >= 0) ? "block" : "none";
      }
    };
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
    document.body.className = (document.body.className || "") + " page-enter";
    buildDrawer();
    buildToc();
    copyButtons();
    filterCards();
    pressFeedback();
  });
})();
