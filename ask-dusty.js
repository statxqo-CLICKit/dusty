// "Ask Dusty": offline scripted help. No network calls, no data collected. Never asks for keys or seed phrases.
(function () {
  var NET = "Base";
  var FAQ = [
    ["connect", "How do I connect my wallet?", "Tap <b>Connect wallet</b>, then pick your wallet (MetaMask, Coinbase Wallet, Rabby…). On a phone, open Dusty inside your wallet app's browser: in MetaMask tap the <b>Browser</b> tab and go to <b>statxqo-clickit.github.io/dusty</b>. Connecting only shares your public address."],
    ["base", "How do I switch to Base?", "Dusty asks your wallet to switch for you. Tap <b>Switch to Base</b> when you see the yellow banner, then approve in your wallet. Manual way in MetaMask: tap the network name at the top and choose <b>Base</b>."],
    ["dust", "What is dust?", "Dust is a tiny leftover token balance, usually a few cents, that is worth less than the gas to move it. It just clutters your wallet. Dusty counts anything under $10 as dust."],
    ["how", "How do I recycle?", "1) Connect your wallet. 2) Sign in (free) or skip. 3) Dusty scans for dust. 4) Tick the dust you want to recycle and tap <b>Recycle dust</b>. 5) Approve the exact amount, then confirm the recycle in your wallet. DUSTY arrives in a few seconds."],
    ["where", "Where does my DUSTY show up?", "In the same wallet you connected, on Base. If you don't see it, add the DUSTY token to your wallet (see below). The success screen also has a Basescan link to your transaction."],
    ["add", "How do I add DUSTY to my wallet?", "On the success screen tap <b>Add $DUSTY to wallet</b> and approve. Or in MetaMask: Tokens → <b>Import tokens</b> → paste the DUSTY contract address shown in the app."],
    ["install", "How do I install the app?", "Android (Chrome): ⋮ menu → <b>Install app</b>. iPhone (Safari): Share → <b>Add to Home Screen</b>. Google Play is coming soon. <a href='welcome.html#install'>Step-by-step</a>"],
    ["fee", "What is the 5% fee?", "Dusty keeps 5% of the DUSTY from each recycle as a recycle fee. Example: if a recycle quotes 1,000 DUSTY, you receive 950. The quote itself follows the DUSTY/USDC pool's 30-minute average price. You also pay a small network gas fee in ETH."],
    ["seed", "Will Dusty ask for my seed phrase?", "<b>Never.</b> Dusty never asks for your seed phrase, recovery words or private key, and neither will anyone from the team. Anyone who asks is a scammer. Don't type them anywhere."]
  ];
  var css = "body{padding-bottom:calc(84px + env(safe-area-inset-bottom))}#ad-b{position:fixed;right:16px;bottom:calc(16px + env(safe-area-inset-bottom));z-index:80;min-height:52px;padding:0 16px 0 12px;border-radius:999px;border:1px solid #39ff14;background:#071a0b;color:#e8fff0;font:700 15px system-ui,sans-serif;display:flex;align-items:center;gap:8px;box-shadow:0 8px 24px -6px rgba(57,255,20,.5);cursor:pointer}" +
    "#ad-b i{font-style:normal;font-size:20px}" +
    "#ad-p{position:fixed;right:12px;left:12px;bottom:calc(78px + env(safe-area-inset-bottom));z-index:81;max-width:400px;margin-left:auto;max-height:min(70vh,560px);display:none;flex-direction:column;background:#0b130e;border:1px solid #2a4a34;border-radius:18px;box-shadow:0 20px 60px -10px #000;color:#e8fff0;font:15px/1.45 system-ui,sans-serif;overflow:hidden}" +
    "#ad-p.on{display:flex}#ad-h{display:flex;align-items:center;justify-content:space-between;padding:10px 10px 10px 14px;border-bottom:1px solid #1f3a2c;font-weight:800}" +
    "#ad-x{min-width:44px;min-height:44px;border:0;background:transparent;color:#e8fff0;font-size:22px;cursor:pointer}" +
    "#ad-m{flex:1;overflow-y:auto;padding:12px 14px;display:flex;flex-direction:column;gap:8px}" +
    ".ad-q{align-self:flex-end;background:#39ff14;color:#05200a;border-radius:14px 14px 4px 14px;padding:8px 12px;max-width:85%;font-weight:600}" +
    ".ad-a{align-self:flex-start;background:#16221a;border:1px solid #1f3a2c;border-radius:14px 14px 14px 4px;padding:9px 12px;max-width:92%}.ad-a a{color:#39ff14}" +
    "#ad-c{display:flex;flex-wrap:wrap;gap:6px;padding:10px 12px 12px;border-top:1px solid #1f3a2c;max-height:42%;overflow-y:auto}" +
    "#ad-c button{min-height:44px;padding:0 12px;border-radius:999px;border:1px solid #2a4a34;background:#0f1a13;color:#cfe6d6;font:600 14px system-ui,sans-serif;cursor:pointer}" +
    "#ad-c button:active{background:#39ff14;color:#05200a}";
  function init() {
    if (document.getElementById("ad-b")) return;
    var st = document.createElement("style"); st.textContent = css; document.head.appendChild(st);
    var b = document.createElement("button"); b.id = "ad-b"; b.type = "button"; b.setAttribute("aria-expanded", "false"); b.setAttribute("aria-controls", "ad-p");
    b.innerHTML = "<i aria-hidden='true'>💬</i>Ask Dusty";
    var p = document.createElement("div"); p.id = "ad-p"; p.setAttribute("role", "dialog"); p.setAttribute("aria-label", "Ask Dusty help");
    p.innerHTML = "<div id='ad-h'><span>♻ Ask Dusty</span><button id='ad-x' type='button' aria-label='Close'>×</button></div><div id='ad-m' aria-live='polite'></div><div id='ad-c'></div>";
    document.body.appendChild(b); document.body.appendChild(p);
    var m = p.querySelector("#ad-m"), c = p.querySelector("#ad-c");
    function add(cls, html) { var d = document.createElement("div"); d.className = cls; d.innerHTML = html; m.appendChild(d); m.scrollTop = m.scrollHeight; }
    add("ad-a", "Hi, I'm Dusty. Tap a question below. I'll never ask for your seed phrase.");
    FAQ.forEach(function (f) {
      var x = document.createElement("button"); x.type = "button"; x.textContent = f[1];
      x.onclick = function () { add("ad-q", f[1]); add("ad-a", f[2]); };
      c.appendChild(x);
    });
    function toggle(on) { p.classList.toggle("on", on); b.setAttribute("aria-expanded", on ? "true" : "false"); }
    b.onclick = function () { toggle(!p.classList.contains("on")); };
    p.querySelector("#ad-x").onclick = function () { toggle(false); b.focus(); };
    document.addEventListener("keydown", function (e) { if (e.key === "Escape") toggle(false); });
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init); else init();
})();
