// Temporary public notice on index.html and welcome.html. Set SHOW_TEST_NOTICE = false to remove it everywhere.
var SHOW_TEST_NOTICE = true;
(function () {
  if (!SHOW_TEST_NOTICE) return;
  function show() {
    if (document.getElementById("dusty-notice")) return;
    var d = document.createElement("div");
    d.id = "dusty-notice";
    d.setAttribute("role", "status");
    d.style.cssText = "position:relative;z-index:50;background:#122016;color:#e8fff0;border-bottom:1px solid #39ff88;padding:9px 14px;font:13px/1.4 system-ui,sans-serif;text-align:center";
    d.appendChild(document.createTextNode("Pool is live. Liquidity locked until Nov 9, 2027. Reserve lock in progress. Details on the "));
    var a = document.createElement("a"); a.href = "transparency.html"; a.textContent = "Transparency page"; a.style.color = "#39ff88"; a.style.fontWeight = "700";
    d.appendChild(a); d.appendChild(document.createTextNode("."));
    document.body.insertBefore(d, document.body.firstChild);
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", show); else show();
})();
