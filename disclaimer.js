// One shared Dusty disclaimer. Every page fills [data-disclaimer] from this string.
window.DUSTY_DISCLAIMER = "Not financial advice. DUSTY is a utility reward with no promised value. Smart contracts carry risk; use at your own risk. See Terms.";
(function () {
  function fill() {
    document.querySelectorAll("[data-disclaimer]").forEach(function (el) {
      var t = window.DUSTY_DISCLAIMER, i = t.lastIndexOf("Terms");
      el.textContent = t.slice(0, i);
      var a = document.createElement("a"); a.href = "terms.html"; a.textContent = "Terms"; el.appendChild(a);
      el.appendChild(document.createTextNode(t.slice(i + 5)));
    });
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", fill); else fill();
})();
