#!/usr/bin/env python3
"""Headless smoke test of every public Dusty page.
Usage: python3 tools/smoke.py [BASE_URL]   (default https://statxqo-clickit.github.io/dusty/)
Needs: pip install playwright; a Chromium at $CHROMIUM (default /usr/bin/chromium).
Checks: HTTP 200, no JS page errors / console errors, no failed same-origin requests, ethers loads,
mainnet config (chainId 8453, token/recycler/USDC addresses), Uniswap buy links. Read-only: nothing is signed or sent."""
import os, re, sys, json, urllib.request
from playwright.sync_api import sync_playwright

BASE = (sys.argv[1] if len(sys.argv) > 1 else "https://statxqo-clickit.github.io/dusty/").rstrip("/") + "/"
CHROME = os.environ.get("CHROMIUM", "/usr/bin/chromium")
TOKEN = "0xAf47E82C6f7cB9E28bB0382a1FeAdBC6308FDDc1".lower()
RECYCLER = "0x199Fef502B969018091294a69e6634DA7aC9e64d".lower()
USDC = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913".lower()
PAGES = ["", "index.html", "welcome.html", "transparency.html", "lock-reserve.html", "seed-pool.html", "sign-message.html",
         "deploy-mainnet.html", "treasury.html", "terms.html"]
STATIC = ["download/Dusty.apk", "manifest.webmanifest", "sw.js", "vendor/ethers-6.15.0.min.js", "disclaimer.js", "get-dusty.js",
          "notice.js", "ask-dusty.js", "countdown.js", "icon-192.png", "icon-512.png", "icon-maskable-512.png", "apple-touch-icon.png",
          "favicon-32.png", "logo-mark.png", "dusty-logo.png"]
# noise that is not a Dusty bug (third-party RPC rate limits, wallet SDK telemetry)
IGNORE = re.compile(r"429|Too Many Requests|ERR_NAME_NOT_RESOLVED|pulse\.walletconnect|favicon\.ico|net::ERR_ABORTED", re.I)
fails = []

def head(url):
    req = urllib.request.Request(url, method="GET", headers={"User-Agent": "dusty-smoke"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.status, r.headers.get("Content-Type", ""), r.read()

for s in STATIC:
    try:
        st, ct, body = head(BASE + s)
        extra = ""
        if s.endswith(".apk"): extra = f" {len(body)} bytes, zip={body[:2] == b'PK'}"; ok = st == 200 and body[:2] == b"PK"
        elif s == "manifest.webmanifest":
            m = json.loads(body); extra = f" name={m.get('name')} start_url={m.get('start_url')}"; ok = st == 200 and m.get("start_url")
        elif s == "sw.js": v = re.search(rb'dusty-shell-v(\d+)', body); extra = f" cache v{v.group(1).decode() if v else '?'}"; ok = st == 200 and v
        else: ok = st == 200
        print(("OK  " if ok else "FAIL"), st, s, extra)
        if not ok: fails.append(s)
    except Exception as e:
        print("FAIL", s, e); fails.append(s)

with sync_playwright() as p:
    b = p.chromium.launch(executable_path=CHROME, args=["--no-sandbox"])
    for path in PAGES:
        ctx = b.new_context(); pg = ctx.new_page()
        errs, bad = [], []
        pg.on("pageerror", lambda e: errs.append("pageerror: " + str(e)))
        pg.on("console", lambda m: m.type == "error" and not IGNORE.search(m.text) and errs.append("console: " + m.text[:200]))
        pg.on("requestfailed", lambda r: (r.url.startswith(BASE) and not IGNORE.search(r.failure or "")) and bad.append(r.url + " " + (r.failure or "")))
        pg.on("response", lambda r: (r.url.startswith(BASE) and r.status >= 400 and not IGNORE.search(r.url)) and bad.append(f"{r.status} {r.url}"))
        try:
            resp = pg.goto(BASE + path, wait_until="load", timeout=45000)
            pg.wait_for_timeout(4000)
            st = resp.status if resp else 0
            html = pg.content().lower()
            notes = []
            ok_eth = pg.evaluate("""async () => { try { const m = await import(new URL('vendor/ethers-6.15.0.min.js', location.href).href);
                       return typeof m.BrowserProvider === 'function' && m.ethers.version } catch (e) { return 'ERR ' + e } }""")
            notes.append(f"ethers={ok_eth}")
            if "ethers@" in html and "cdn.jsdelivr" in html: notes.append("STILL-CDN-ETHERS"); errs.append("page still loads ethers from CDN")
            for u in re.findall(r'https://app\.uniswap\.org/[^"\'<> ]+', html):
                u = u.replace("&amp;", "&")
                if "/positions/" in u: continue  # LP position link (transparency page), no token params
                if "base" not in u or (TOKEN not in u and USDC not in u): errs.append("uniswap link wrong: " + u)
                else: notes.append("uniswap ok")
            # links built at runtime
            for a in pg.eval_on_selector_all("a[href*='uniswap']", "els => els.map(e => e.href)"):
                al = a.lower()
                if not ("chain=base" in al and TOKEN in al and USDC in al): errs.append("uniswap href wrong: " + a)
                else: notes.append("uniswap href ok")
            if "1,000 dusty per $1" in html or "1000 dusty per $1" in html: errs.append("fixed 1,000/$1 claim present")
            if path in ("transparency.html", "terms.html") and "30-minute average price" not in html: errs.append("payout disclosure missing")
            if path in ("", "index.html"):
                if '"0x2105"' not in html or "chainid: 8453" not in html: errs.append("mainnet chain config missing")
                if TOKEN not in html or RECYCLER not in html: errs.append("token/recycler address missing")
                if "30-minute average price" not in html: errs.append("payout disclosure missing")
                wc = pg.evaluate("""async () => { try { const r = await fetch('https://esm.sh/@walletconnect/ethereum-provider@2.26.0'); return r.status } catch (e) { return 'ERR ' + e } }""")
                notes.append(f"walletconnect-module={wc}")
                if wc != 200: errs.append(f"WalletConnect module not reachable ({wc})")
            print(("OK  " if st == 200 and not errs and not bad else "FAIL"), st, path or "/", " ".join(sorted(set(notes))))
            for e in errs + bad: print("     ", e)
            if st != 200 or errs or bad: fails.append(path or "/")
        except Exception as e:
            print("FAIL", path, e); fails.append(path or "/")
        ctx.close()
    b.close()
print("\nRESULT:", "ALL PASS" if not fails else "FAILURES: " + ", ".join(fails))
sys.exit(1 if fails else 0)
