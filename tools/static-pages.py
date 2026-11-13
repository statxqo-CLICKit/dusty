#!/usr/bin/env python3
"""Writes how-it-works.html, contracts.html, security.html and .well-known/security.txt. Then run tools/seo.py."""
import pathlib
root = pathlib.Path(__file__).resolve().parent.parent
BS = "https://basescan.org/address/"
CSS = """*{box-sizing:border-box}body{margin:0;background:radial-gradient(120% 50% at 50% 0%,#0f2a14 0%,#060708 60%);color:#e8fff0;font:16px/1.6 system-ui,-apple-system,Segoe UI,Roboto,sans-serif}
main{max-width:760px;margin:0 auto;padding:20px 18px 72px}a{color:#39ff14}h1{font-size:clamp(28px,7vw,42px);line-height:1.1;margin:14px 0 8px}h1 span{color:#39ff14}
h2{color:#b6ff3b;font-size:20px;margin:30px 0 8px}p,li{color:#cfe6d6}.lead{font-size:18px;color:#bcd6c4}
.top{display:flex;align-items:center;gap:10px;font-weight:800;font-size:19px;text-decoration:none;color:#e8fff0}.top img{width:36px;height:36px;border-radius:9px}
.card{background:#0b130e;border:1px solid #1f3a2c;border-radius:14px;padding:16px;margin:12px 0}
.steps{display:grid;gap:12px;padding:0;margin:0;list-style:none;counter-reset:s}.steps li{counter-increment:s;background:#0b130e;border:1px solid #1f3a2c;border-radius:14px;padding:14px 14px 14px 58px;position:relative}
.steps li::before{content:counter(s);position:absolute;left:14px;top:14px;width:32px;height:32px;border-radius:50%;background:#39ff14;color:#05200a;font-weight:900;display:flex;align-items:center;justify-content:center}
.steps b{color:#e8fff0}.btn{display:inline-flex;align-items:center;justify-content:center;min-height:48px;padding:0 20px;border-radius:12px;font-weight:800;text-decoration:none;border:0;cursor:pointer;font-size:16px}
.btn.p{background:linear-gradient(180deg,#7dff5a,#39ff14 45%,#22c00a);color:#05200a}.btn.s{background:#16221a;color:#e8fff0;border:1px solid #2a4a34}
.row2{display:flex;gap:10px;flex-wrap:wrap;margin:16px 0}
table{width:100%;border-collapse:collapse;font-size:14px}td{padding:9px 6px;border-top:1px solid #1f3a2c;vertical-align:top}td:first-child{color:#a9c4b4;width:38%}
code{font:13px ui-monospace,Menlo,Consolas,monospace;word-break:break-all;color:#b6ff3b}
.warn{border:1px solid #5a4a12;background:#16120a;border-radius:12px;padding:14px;color:#ffe08a}
footer{margin-top:36px;text-align:center;font-size:14px;color:#6c8a78;line-height:2}footer a{margin:0 4px}
.demo{position:relative;background:#060708;border:1px dashed #39ff14;border-radius:16px;padding:16px;margin:12px 0}
.demo .tag{position:absolute;top:-11px;left:14px;background:#39ff14;color:#05200a;font-weight:900;font-size:12px;letter-spacing:.08em;padding:2px 8px;border-radius:6px}
.dr{display:flex;align-items:center;gap:10px;background:#0d1714;border:1px solid #1f3a2c;border-radius:12px;padding:10px 12px;margin:8px 0;font:14px ui-monospace,Menlo,monospace;cursor:pointer}
.dr input{width:20px;height:20px;accent-color:#39ff14}.dr span{flex:1}.dr small{color:#6c8;font-family:system-ui}
.dst{min-height:24px;color:#a9c4b4;font-size:14px;margin:8px 0}.got{text-align:center;background:#071a0b;border:1px solid #39ff14;border-radius:12px;padding:12px;font-weight:800;color:#39ff14;font-size:18px}
video{display:block;width:min(320px,100%);margin:12px auto;border-radius:16px;border:1px solid #1f3a2c;background:#000}[hidden]{display:none!important}"""
FOOT = """<footer><a href="./">Open the app</a>·<a href="how-it-works.html">How it works</a>·<a href="contracts.html">Contracts</a>·<a href="transparency.html">Transparency</a>·<a href="security.html">Security</a>·<a href="terms.html">Terms</a>·<a href="https://x.com/DUSTYappsocial" rel="noopener">X @DUSTYappsocial</a><br>Built on Base by Team C.L.I.C.K.it · Contracts are unaudited · Not financial advice</footer>"""
def page(title, body, script=""):
    return f"""<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title>{title}</title>
<link rel="icon" href="favicon-32.png"><link rel="apple-touch-icon" href="apple-touch-icon.png"><meta name="theme-color" content="#060708">
<style>{CSS}</style></head>
<body><main>
<a class="top" href="./"><img src="logo-mark.png" alt="">dusty</a>
{body}
{FOOT}
</main>{script}</body></html>
"""
C = [("DUSTY token (ERC-20)", "0xAf47E82C6f7cB9E28bB0382a1FeAdBC6308FDDc1", "The DUSTY token. New DUSTY can only be minted by the Recycler, for recycled dust, within hard limits."),
     ("DustyRecycler", "0x199Fef502B969018091294a69e6634DA7aC9e64d", "Takes the dust you tick (exact-amount approval only) and sends you DUSTY, minus the 5% recycle fee."),
     ("Treasury · 0xSplits 50/50", "0x571E955471E93251d2a708Ea107eb86919639710", "Receives the recycle fee and splits it 50/50 between the two team wallets. Every payout is public."),
     ("Uniswap v3 pool · USDC/DUSTY 1%", "0x4E74fFa1eb8d549a772673939946599246f854B3", "The only official DUSTY pool. Payouts follow its 30-minute average rate."),
     ("Liquidity lock", "0xacCED9C10915F0587D2f37215438f1E0c71b5ee6", "Holds Uniswap position NFT #6525151. The pool's liquidity cannot be removed until Nov 9, 2027, 9:40 PM PST."),
     ("Reserve lock", "0xE3B591e0ED01803CEC7AfcDAa94e65946e7C87A3", "Holds 4,500,000 DUSTY from the Dusty Rewards Reserve until Nov 9, 2027, 9:40 PM PST. No owner, no early withdraw.")]
rows = "".join(f'<tr><td><b style="color:#e8fff0">{n}</b><br><small>{d}</small></td><td><code>{a}</code><br><a href="{BS}{a}#code" rel="noopener">View verified code on Basescan ›</a></td></tr>' for n, a, d in C)
contracts = page("Dusty contracts", f"""<h1>Dusty <span>contracts</span></h1>
<p class="lead">Every Dusty contract on Base mainnet (chain 8453). All source code is verified on Basescan, so anyone can read exactly what it does.</p>
<div class="warn">Only trust these addresses. Copies and lookalike tokens named "Dusty" exist on other chains and on Base. The official DUSTY token is <code>0xAf47E82C6f7cB9E28bB0382a1FeAdBC6308FDDc1</code>.</div>
<div class="card"><table>{rows}</table></div>
<h2>Locks until November 9, 2027</h2>
<div class="card"><table>
<tr><td>Liquidity lock</td><td>Uniswap v3 position #6525151 (USDC/DUSTY 1%) locked until <b>Nov 9, 2027, 9:40 PM PST</b>. While locked, the liquidity cannot be removed or moved.</td></tr>
<tr><td>Reserve lock</td><td><b>4,500,000 DUSTY</b> locked until <b>Nov 9, 2027, 9:40 PM PST</b>. After that it can only return to the Dusty Rewards Reserve wallet.</td></tr>
</table></div>
<p>Want the live numbers (supply, balances, limits)? The <a href="transparency.html">Transparency page</a> reads them straight from the chain each time you open it.</p>
<p><small style="color:#8fb09b">Contracts are unaudited. This page lists facts only; it is not an offer or a solicitation.</small></p>""")

security = page("Dusty security", """<h1>Dusty <span>security</span></h1>
<p class="lead">How to report a problem, and how to stay safe while you recycle.</p>
<h2>Stay safe</h2>
<ul>
<li><b>Dusty never asks for your seed phrase or private key.</b> Not in the app, not on X, not in DMs. Anyone who asks is a scammer.</li>
<li>Dusty never asks you to send tokens to a person. Recycling happens only through the verified Recycler contract, and you confirm every step in your own wallet.</li>
<li>Approvals are for the exact amount you recycle, never unlimited.</li>
<li>Only use the official site <a href="./">statxqo-clickit.github.io/dusty</a> and the official X account <a href="https://x.com/DUSTYappsocial" rel="noopener">@DUSTYappsocial</a>.</li>
<li>Check addresses against the <a href="contracts.html">verified contract list</a>. Lookalike "Dusty" tokens exist.</li>
</ul>
<h2>Report a vulnerability</h2>
<p>Found a bug in the contracts, the app or this site? Please tell us privately first and give us a fair chance to fix it before sharing it publicly.</p>
<ul>
<li>Send a direct message to <a href="https://x.com/DUSTYappsocial" rel="noopener">@DUSTYappsocial</a> on X with "Security" in the first line. Or use <a href="https://github.com/statxqo-CLICKit/dusty/security/advisories/new" rel="noopener">GitHub private vulnerability reporting</a> if it is open on the repo.</li>
<li>Include what you found, the steps to reproduce it, and the contract or page involved.</li>
<li>Do not include seed phrases, private keys or anyone's personal data. We will never ask for them.</li>
<li>Please act in good faith: no testing that moves other people's funds, no denial-of-service, no social engineering.</li>
</ul>
<p>We read every report and aim to reply within 3 days. Machine-readable contact: <a href="https://statxqo-clickit.github.io/dusty/.well-known/security.txt">security.txt</a>.</p>
<h2>Scope</h2>
<p>The contracts on the <a href="contracts.html">contracts page</a>, the Dusty web app and this site. Contracts are unaudited; their source is verified on Basescan.</p>""")

how = page("How Dusty works", """<h1>Recycle your <span>dust</span></h1>
<p class="lead">Dust is the tiny leftover balance a token leaves behind in your wallet: a few cents of USDC after a swap, a fraction left from a payment. It is often too small to be worth moving on its own, so it just sits there. Dusty turns it into DUSTY on Base.</p>
<div class="row2"><a class="btn p" href="./">♻ Open the app</a><a class="btn s" href="#demo">▶ Try the demo</a></div>
<h2>Three steps</h2>
<ol class="steps">
<li><b>Connect.</b> Open Dusty and connect the wallet you already use: MetaMask, Coinbase Wallet, Rabby, or any mobile wallet through WalletConnect. On a phone, open Dusty inside your wallet app's browser.</li>
<li><b>Tick your dust.</b> Dusty reads your balances and lists the dust it can recycle. Today that is small USDC balances on Base; other dust is shown as coming soon. Tick the bits you want to clear.</li>
<li><b>Confirm and receive DUSTY.</b> Dusty shows the exact DUSTY you will receive, after the fee, before you sign anything. Confirm in your own wallet (the first time, your wallet also asks to approve that exact amount) and DUSTY lands in your wallet.</li>
</ol>
<h2>Good to know</h2>
<div class="card"><table>
<tr><td>Recycle fee</td><td>5%, taken in DUSTY. The amount you see before confirming is already after the fee.</td></tr>
<tr><td>How the amount is set</td><td>Payouts follow the DUSTY/USDC Uniswap pool's 30-minute average rate. The pool is small, so the rate can move a lot.</td></tr>
<tr><td>Network gas</td><td>You pay Base gas in ETH, as with any transaction. Dusty never receives it.</td></tr>
<tr><td>Your keys</td><td><b>Dusty never asks for your seed phrase or private key.</b> Every step is confirmed in your own wallet.</td></tr>
<tr><td>Approvals</td><td>Exact amount only, never unlimited.</td></tr>
<tr><td>Audit status</td><td>The contracts are <b>unaudited</b>. Their source is verified on Basescan: see the <a href="contracts.html">contracts</a>.</td></tr>
</table></div>
<h2 id="demo">Try it without a wallet</h2>
<div class="demo"><span class="tag">DEMO</span>
<p style="margin:6px 0 10px;font-size:14px;color:#a9c4b4">A simulation with made-up balances. Nothing connects, nothing is signed, nothing is sent.</p>
<div id="d1"><button class="btn p" id="dConnect" type="button" style="width:100%">1 · Connect (demo wallet)</button></div>
<div id="d2" hidden><div class="dst">Demo wallet <code>0xDEMO…D057</code> · dust found on Base:</div>
<label class="dr"><input type="checkbox" data-a="0.41"><span>0.41 USDC</span><small>dust</small></label>
<label class="dr"><input type="checkbox" data-a="0.92"><span>0.92 USDC</span><small>dust</small></label>
<label class="dr"><input type="checkbox" data-a="0.07"><span>0.07 USDC</span><small>dust</small></label>
<button class="btn p" id="dGo" type="button" style="width:100%;margin-top:6px" disabled>2 · Tick your dust</button></div>
<div id="d3" hidden><div class="dst" id="dStat"></div><div class="got" id="dGot" hidden></div>
<button class="btn s" id="dAgain" type="button" style="width:100%;margin-top:10px" hidden>↺ Run the demo again</button></div>
</div>
<h2>Watch: Dusty in 15 seconds</h2>
<video controls playsinline preload="none" poster="media/dusty-launch-poster.jpg" src="media/dusty-launch-15s.mp4"></video>
<div class="row2" style="justify-content:center"><a class="btn p" href="./">♻ Recycle my dust</a></div>""",
"""<script>
(function(){var $=function(i){return document.getElementById(i)},boxes=[].slice.call(document.querySelectorAll('#d2 input'));
function sum(){return boxes.filter(function(b){return b.checked}).reduce(function(n,b){return n+ +b.dataset.a},0)}
boxes.forEach(function(b){b.onchange=function(){var s=sum();$('dGo').disabled=!s;$('dGo').textContent=s?'3 · Confirm ('+s.toFixed(2)+' USDC of dust)':'2 · Tick your dust'}});
$('dConnect').onclick=function(){this.textContent='Connecting demo wallet…';setTimeout(function(){$('d1').hidden=true;$('d2').hidden=false},700)};
$('dGo').onclick=function(){var s=sum();$('d2').hidden=true;$('d3').hidden=false;var st=$('dStat');
 var steps=['Showing you the DUSTY amount after the 5% fee…','Waiting for your confirmation in your wallet (demo)…','Recycling on Base (demo)…'];var i=0;
 (function next(){if(i<steps.length){st.textContent=steps[i++];setTimeout(next,900)}else{st.textContent='Done. Your dust is cleared (demo).';$('dGot').hidden=false;$('dGot').textContent='+ DUSTY received (demo amount)';$('dAgain').hidden=false}})()};
$('dAgain').onclick=function(){boxes.forEach(function(b){b.checked=false});$('dGo').disabled=true;$('dGo').textContent='2 · Tick your dust';$('d3').hidden=true;$('dGot').hidden=true;$('dAgain').hidden=true;$('d1').hidden=false;$('dConnect').textContent='1 · Connect (demo wallet)'};
})();
</script>""")
(root / "contracts.html").write_text(contracts)
(root / "security.html").write_text(security)
(root / "how-it-works.html").write_text(how)
(root / ".well-known/security.txt").write_text("""Contact: https://x.com/DUSTYappsocial
Contact: https://github.com/statxqo-CLICKit/dusty/security/advisories/new
Expires: 2027-11-12T23:59:00-08:00
Preferred-Languages: en
Canonical: https://statxqo-clickit.github.io/dusty/.well-known/security.txt
Policy: https://statxqo-clickit.github.io/dusty/security.html
""")
print("ok")
