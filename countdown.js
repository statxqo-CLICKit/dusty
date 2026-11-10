// Dusty launch countdown banner. Target is a fixed instant (9:47 pm Pacific, Nov 9 2026);
// the visitor's own clock counts down to it and the local launch time is shown.
(function () {
  var TARGET = Date.parse("2026-11-09T21:47:00-08:00");
  var LINE = "Recycle any dust in your wallet and receive DUSTY";
  var css = "#x-launch{position:sticky;top:0;z-index:60;display:flex;flex-wrap:wrap;align-items:center;justify-content:center;gap:4px 10px;" +
    "padding:10px 14px;min-height:44px;box-sizing:border-box;background:#0b130e;border-bottom:1px solid #1f3a2c;color:#e8fff0;" +
    "font:600 14px/1.35 system-ui,-apple-system,Segoe UI,Roboto,sans-serif;text-align:center}" +
    "#x-launch b{color:#b6ff3b;font-variant-numeric:tabular-nums;font-family:ui-monospace,Menlo,Consolas,monospace}" +
    "#x-launch small{color:#a9c4b4;font-weight:500;font-size:12px;width:100%}";
  function init() {
    if (document.getElementById("x-launch")) return;
    var st = document.createElement("style"); st.textContent = css; document.head.appendChild(st);
    var el = document.createElement("div"); el.id = "x-launch"; el.setAttribute("role", "status");
    document.body.insertBefore(el, document.body.firstChild);
    var local = new Date(TARGET).toLocaleString([], { weekday: "short", hour: "numeric", minute: "2-digit", timeZoneName: "short" });
    var p2 = function (n) { return (n < 10 ? "0" : "") + n; };
    function tick() {
      var ms = TARGET - Date.now();
      if (ms <= 0) { el.innerHTML = "<span>\u267B Dusty is <b>Live now</b> \u2014 " + LINE + "</span>"; return; }
      var s = Math.floor(ms / 1000), h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
      el.innerHTML = "<span>Dusty launches in <b>" + p2(h) + ":" + p2(m) + ":" + p2(s % 60) + "</b> \u2014 " + LINE + "</span><small>Launch: " + local + "</small>";
    }
    var big = document.querySelectorAll("[data-countdown]");
    function tickBig() {
      var ms = TARGET - Date.now();
      big.forEach(function (b) {
        if (ms <= 0) { b.innerHTML = "<b>Live now</b>"; return; }
        var s = Math.floor(ms / 1000), d = Math.floor(s / 86400), h = Math.floor((s % 86400) / 3600), m = Math.floor((s % 3600) / 60);
        b.innerHTML = (d ? "<span><b>" + d + "</b><i>days</i></span>" : "") + "<span><b>" + p2(h) + "</b><i>hrs</i></span><span><b>" + p2(m) + "</b><i>min</i></span><span><b>" + p2(s % 60) + "</b><i>sec</i></span>";
      });
    }
    window.DUSTY_LAUNCH = TARGET;
    var t = setInterval(function () { tick(); tickBig(); }, 1000); tick(); tickBig();
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init); else init();
})();
