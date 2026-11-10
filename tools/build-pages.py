#!/usr/bin/env python3
"""Regenerate deploy.html, recycler.html, deploy-mainnet.html and seed-pool.html from tools/*.tpl.html and the Foundry build in out/.
Run `forge build` first. Embeds the exact ABI + bytecode that the tests ran against."""
import json, pathlib
root = pathlib.Path(__file__).resolve().parent.parent
def art(n): return json.loads((root / f"out/{n}.sol/{n}.json").read_text())
tok, rec = art("DustyToken"), art("DustyRecycler")
sub = {
    "__TOKEN_ABI__": json.dumps(tok["abi"], separators=(",", ":")),
    "__REC_ABI__": json.dumps(rec["abi"], separators=(",", ":")),
    "__TOKEN_BC__": tok["bytecode"]["object"],
    "__REC_BC__": rec["bytecode"]["object"],
    "__USDC__": "0x036CbD53842c5426634e7929541eC2318f3dCF7e",  # Base Sepolia USDC (Circle)
}
import hashlib
SIGNER_FILE = pathlib.Path("/workspace/projects/1f70029c-db9d-4eb4-8076-a31096ed8560/secrets/mainnet-signer.address")
main = dict(sub)
main["__USDC__"] = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"  # Base mainnet USDC (Circle)
main["__SIGNER__"] = SIGNER_FILE.read_text().strip() if SIGNER_FILE.exists() else "0xE3ed6685AcB201EB40370d181766424C00F2515f"
main["__BC_SHA__"] = hashlib.sha256((tok["bytecode"]["object"] + rec["bytecode"]["object"]).encode()).hexdigest()
# Uniswap v3 on Base mainnet, from https://docs.uniswap.org/contracts/v3/reference/deployments/base-deployments
# (checked with eth_getCode on mainnet.base.org; NPM.factory() == Factory)
main["__V3_FACTORY__"] = "0x33128a8fC17869897dcE68Ed026d694621f6FDfD"
main["__V3_NPM__"] = "0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1"
# 0xSplits v1 on Base 8453, from https://docs.splits.org/core/split (source: github.com/0xSplits/docs pages/core/split.mdx)
# checked with eth_getCode on mainnet.base.org (SplitMain 12693 bytes; walletImplementation() == SplitWallet 0xD94c…3B33; PERCENTAGE_SCALE 1e6)
main["__SPLIT_MAIN__"] = "0x2ed6c4B5dA6378c7897AC67Ba9e43102Feb694EE"
main["__MULTICALL3__"] = "0xcA11bde05977b3631167028862bE2a173976CA11"  # Multicall3 (code checked on Base)
main["__STAN__"] = "0x9b8EBB1490E823bB152aCd64B198Df4d1035c7Fd"
main["__ANDREA__"] = "0x4eCDF3cA4BDc6Ee3257267384cf3915B49a585F2"
main["__RESERVE__"] = "0x4F9eb9a29c174Ec2a087545275Bf1e9070ef108C"  # DUSTY Partner Allocation Wallet (Stan, 2026-11-09); amount stays 0 until decided
LOGO = "https://statxqo-clickit.github.io/dusty/token/dusty-256.png"
main["__LOGO_URL__"] = LOGO
sub["__LOGO_URL__"] = LOGO
for name, subs in (("deploy", sub), ("recycler", sub), ("deploy-mainnet", main), ("seed-pool", main), ("treasury", main)):
    s = (root / f"tools/{name}.tpl.html").read_text()
    for k, v in subs.items(): s = s.replace(k, v)
    import re as _re
    left = _re.findall(r"__[A-Z0-9_]+__", s)
    assert not left, (name, left)
    assert "__" + "TOKEN_BC__" not in s and "__" + "V3_" not in s and "__" + "USDC__" not in s
    (root / f"{name}.html").write_text(s)
    print(name + ".html", len(s), "bytes")
