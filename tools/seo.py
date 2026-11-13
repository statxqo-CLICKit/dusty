#!/usr/bin/env python3
"""SEO + security meta for Dusty's public pages. Idempotent: re-run any time.
Writes the block between <!--seo--> and <!--/seo--> right after </title>, strips older og:/twitter:/description/canonical tags,
and regenerates sitemap.xml. Run after tools/build-pages.py (transparency.html is generated from its template)."""
import json, pathlib, re, datetime
root = pathlib.Path(__file__).resolve().parent.parent
BASE = "https://statxqo-clickit.github.io/dusty/"
IMG = BASE + "token/dusty-og-1200x630.png"
X = "https://x.com/DUSTYappsocial"
CR = "https://coinranking.com/coin/ZXRnUifLp+dusty-dusty"
TOKEN = "0xAf47E82C6f7cB9E28bB0382a1FeAdBC6308FDDc1"
# Loose CSP for pages that talk to wallets/RPC/WalletConnect: blocks plugins, <base> hijack and mixed content only.
CSP_APP = "object-src 'none'; base-uri 'self'; upgrade-insecure-requests"
# Tight CSP for static pages with no wallet code.
CSP_STATIC = ("default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; "
              "media-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'self'; form-action 'none'; upgrade-insecure-requests")
ORG = {"@type": "Organization", "@id": BASE + "#org", "name": "Dusty", "alternateName": "Dusty Recycler", "url": BASE,
       "logo": BASE + "token/dusty-logo-1024.png", "sameAs": [X, CR],
       "parentOrganization": {"@type": "Organization", "name": "Team C.L.I.C.K.it"}}
APP = {"@type": "WebApplication", "@id": BASE + "#app", "name": "Dusty · Dust Recycler", "url": BASE,
       "applicationCategory": "FinanceApplication", "operatingSystem": "Web, Android",
       "description": "Recycle the tiny leftover balances (dust) in your crypto wallet and receive DUSTY on Base. You confirm in your own wallet; Dusty never asks for a seed phrase.",
       "image": IMG, "publisher": {"@id": BASE + "#org"}, "sameAs": [X, CR],
       "isAccessibleForFree": True, "softwareHelp": BASE + "how-it-works.html"}

# path, title, description, priority, changefreq, csp
PAGES = [
    ("", "Dusty · Dust Recycler on Base", "Recycle the tiny leftover balances in your wallet and receive DUSTY on Base. Connect, tick your dust, confirm in your own wallet. Never asks for a seed phrase.", "1.0", "weekly", CSP_APP, "index.html"),
    ("welcome.html", "Dusty · Recycle your wallet dust", "Those tiny leftover balances are too small to swap. Dusty turns wallet dust into DUSTY on Base in a few taps. Install on Android or iPhone.", "0.9", "weekly", CSP_APP, "welcome.html"),
    ("how-it-works.html", "How Dusty works · Recycle your dust", "What wallet dust is and how Dusty recycles it into DUSTY on Base in 3 steps: connect, tick your dust, confirm. 5% recycle fee. Try the no-wallet demo.", "0.9", "monthly", CSP_STATIC, "how-it-works.html"),
    ("contracts.html", "Dusty contracts · Verified on Basescan", "Every Dusty smart contract on Base mainnet with Basescan links: DUSTY token, DustyRecycler, 50/50 fee split, Uniswap v3 pool, liquidity lock and reserve lock to Nov 9, 2027.", "0.8", "monthly", CSP_STATIC, "contracts.html"),
    ("transparency.html", "Dusty · Transparency", "Dusty (DUSTY) on Base: supply, the Dusty Rewards Reserve, the reserve and liquidity locks, minting limits, fee split and contract addresses, read live from the chain.", "0.8", "weekly", CSP_APP, "transparency.html"),
    ("security.html", "Dusty · Security and responsible disclosure", "How to report a security issue in Dusty, how to stay safe (Dusty never asks for a seed phrase), and the official verified contract list.", "0.6", "monthly", CSP_STATIC, "security.html"),
    ("terms.html", "Dusty · Terms", "Dusty terms of use in plain language: how recycling works, the 5% fee, risks, and what Dusty is not.", "0.4", "monthly", CSP_STATIC, "terms.html"),
]

def block(path, title, desc, csp):
    url = BASE + path
    graph = [ORG, APP] if path == "" else [ORG, {"@type": "WebPage", "@id": url, "url": url, "name": title, "description": desc,
             "isPartOf": {"@id": BASE + "#app"}, "publisher": {"@id": BASE + "#org"}}]
    if path == "how-it-works.html":
        graph.append({"@type": "HowTo", "name": "Recycle your wallet dust with Dusty", "step": [
            {"@type": "HowToStep", "position": 1, "name": "Connect", "text": "Open Dusty and connect your wallet (MetaMask, Coinbase Wallet, Rabby or WalletConnect)."},
            {"@type": "HowToStep", "position": 2, "name": "Tick your dust", "text": "Dusty scans your balances and lists the dust it can recycle. Tick the bits you want to clear."},
            {"@type": "HowToStep", "position": 3, "name": "Confirm and receive DUSTY", "text": "Check the DUSTY amount shown after the 5% fee, confirm in your own wallet, and DUSTY lands in your wallet."}]})
    ld = json.dumps({"@context": "https://schema.org", "@graph": graph}, separators=(",", ":"))
    e = lambda s: s.replace("&", "&amp;").replace('"', "&quot;")
    verify = '<meta name="msvalidate.01" content="E278ECBEB4982714A5B5FAE1A43221BA">\n' if path == "" else ""
    return ("<!--seo-->\n" + verify +
            f'<meta http-equiv="Content-Security-Policy" content="{csp}">\n'
            '<meta name="referrer" content="strict-origin-when-cross-origin">\n'
            f'<meta name="description" content="{e(desc)}">\n'
            f'<link rel="canonical" href="{url}">\n'
            '<meta property="og:type" content="website"><meta property="og:site_name" content="Dusty">\n'
            f'<meta property="og:title" content="{e(title)}"><meta property="og:description" content="{e(desc)}">\n'
            f'<meta property="og:url" content="{url}"><meta property="og:image" content="{IMG}">\n'
            '<meta property="og:image:width" content="1200"><meta property="og:image:height" content="630"><meta property="og:image:alt" content="Dusty: recycle your wallet dust">\n'
            '<meta name="twitter:card" content="summary_large_image"><meta name="twitter:site" content="@DUSTYappsocial">\n'
            f'<meta name="twitter:title" content="{e(title)}"><meta name="twitter:description" content="{e(desc)}"><meta name="twitter:image" content="{IMG}">\n'
            f'<script type="application/ld+json">{ld}</script>\n'
            "<!--/seo-->")

STRIP = re.compile(r'[ \t]*<meta\s+(?:property|name)="(?:og:[^"]*|twitter:[^"]*|description|referrer)"\s+content="[^"]*"\s*/?>[ \t]*\n?|[ \t]*<link\s+rel="canonical"[^>]*>[ \t]*\n?')

def apply(f, path, title, desc, csp):
    s = f.read_text()
    s = re.sub(r"<!--seo-->.*?<!--/seo-->\n?", "", s, flags=re.S)
    s = STRIP.sub("", s)
    s = re.sub(r"<title>.*?</title>", lambda m: f"<title>{title}</title>\n" + block(path, title, desc, csp), s, count=1, flags=re.S)
    f.write_text(s)

for path, title, desc, pr, cf, csp, fname in PAGES:
    apply(root / fname, path, title, desc, csp)
    if fname == "transparency.html":
        apply(root / "tools/transparency.tpl.html", path, title, desc, csp)

from zoneinfo import ZoneInfo
today = datetime.datetime.now(ZoneInfo("America/Los_Angeles")).date().isoformat()
urls = "".join(f"  <url><loc>{BASE}{p}</loc><lastmod>{today}</lastmod><changefreq>{cf}</changefreq><priority>{pr}</priority></url>\n" for p, _, _, pr, cf, _, _ in PAGES)
(root / "sitemap.xml").write_text(f'<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n{urls}</urlset>\n')
print("ok", len(PAGES), "pages")
