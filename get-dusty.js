// "Get DUSTY on Uniswap" link. Read-only: checks Base mainnet for the DUSTY/USDC 1% Uniswap v3 pool
// (factory.getPool + pool.liquidity() > 0) and only then enables every <a data-uniswap>. Never signs anything.
(function () {
  var DUSTY = "0xAf47E82C6f7cB9E28bB0382a1FeAdBC6308FDDc1";
  var USDC = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
  var FACTORY = "0x33128a8fC17869897dcE68Ed026d694621f6FDfD"; // Uniswap v3 Factory on Base
  var FEE = 10000; // 1% tier
  // Uniswap deep-link format: github.com/Uniswap/interface apps/web/src/features/deepLinking/README.md
  var SWAP_URL = "https://app.uniswap.org/swap?chain=base&inputCurrency=" + USDC + "&outputCurrency=" + DUSTY;
  var RPCS = ["https://mainnet.base.org", "https://base-rpc.publicnode.com", "https://base.gateway.tenderly.co"];
  var ON = "Get DUSTY on Uniswap", SOON = "Uniswap pool opening soon", CHECK = "Checking Uniswap pool…";
  var pad = function (h) { return h.toLowerCase().replace(/^0x/, "").padStart(64, "0"); };
  function els() { return document.querySelectorAll("a[data-uniswap]"); }
  function set(state) {
    els().forEach(function (a) {
      var t = a.querySelector("[data-uniswap-label]") || a;
      if (state === "on") {
        a.href = SWAP_URL; a.target = "_blank"; a.rel = "noopener"; a.removeAttribute("aria-disabled"); a.removeAttribute("tabindex");
        a.classList.remove("is-off"); a.title = "Opens Uniswap (Base). Swaps happen on Uniswap, not Dusty.";
        t.textContent = ON;
      } else {
        a.removeAttribute("href"); a.setAttribute("aria-disabled", "true"); a.setAttribute("tabindex", "-1"); a.classList.add("is-off");
        a.title = state === "err" ? "Couldn't reach Base to check the pool. Reload to check again." : "";
        t.textContent = state === "check" ? CHECK : state === "err" ? "Couldn't check Uniswap pool · reload" : SOON;
      }
    });
  }
  function call(url, to, data) {
    return fetch(url, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "eth_call", params: [{ to: to, data: data }, "latest"] }) })
      .then(function (r) { return r.json(); })
      .then(function (j) { if (j.error || typeof j.result !== "string") throw new Error("rpc"); return j.result; });
  }
  function check(url) {
    return call(url, FACTORY, "0x1698ee82" + pad(DUSTY) + pad(USDC) + pad(FEE.toString(16))).then(function (r) {
      var pool = "0x" + r.slice(-40);
      if (/^0x0{40}$/.test(pool)) return false;
      return call(url, pool, "0x1a686502").then(function (l) { return BigInt(l) > 0n; });
    });
  }
  function run() {
    if (!els().length) return;
    set("check");
    var i = 0;
    (function next() {
      if (i >= RPCS.length) { set("err"); return; }
      check(RPCS[i++]).then(function (live) { set(live ? "on" : "soon"); }, next);
    })();
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", run); else run();
})();
