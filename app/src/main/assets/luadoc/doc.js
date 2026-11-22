/* 手册通用交互：目录生成、代码复制、目录页搜索 */
(function () {
  function ready(fn) {
    if (document.readyState === "complete" || document.readyState === "interactive") {
      setTimeout(fn, 0);
    } else {
      document.addEventListener("DOMContentLoaded", fn, false);
    }
  }

  function buildToc() {
    var holder = document.getElementById("auto-toc");
    if (!holder) { return; }
    var heads = document.getElementsByTagName("h2");
    if (!heads.length) { holder.style.display = "none"; return; }
    var html = "<strong>本页目录</strong><ul>";
    for (var i = 0; i < heads.length; i++) {
      var anchor = "sec-" + i;
      heads[i].id = anchor;
      html += '<li><a href="#' + anchor + '">' + heads[i].innerHTML.replace(/<[^>]+>/g, "") + "</a></li>";
    }
    holder.innerHTML = html + "</ul>";
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

  function backToTop() {
    var tops = document.getElementsByClassName("to-top");
    for (var i = 0; i < tops.length; i++) {
      tops[i].onclick = function () { window.scrollTo(0, 0); };
    }
  }

  ready(function () {
    buildToc();
    copyButtons();
    filterCards();
    backToTop();
  });
})();
