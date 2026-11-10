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
main["__RESERVE__"] = "0x4F9eb9a29c174Ec2a087545275Bf1e9070ef108C"  # Dusty Rewards Reserve wallet (Stan's; renamed from "Partner allocation" 2026-11-09)
# Mainnet v2 (deployed 2026-11-09, block 55486854)
main["__DUSTY__"] = "0xAf47E82C6f7cB9E28bB0382a1FeAdBC6308FDDc1"
main["__RECYCLER__"] = "0x199Fef502B969018091294a69e6634DA7aC9e64d"
main["__SPLIT__"] = "0x571E955471E93251d2a708Ea107eb86919639710"
main["__DEPLOY_BLOCK__"] = "55486854"
# DustyReserveLock: 4,500,000 DUSTY locked until 2027-11-09 21:40 PST (= 2027-11-10 05:40 UTC)
lk = art("DustyReserveLock")
_refs = lk["deployedBytecode"]["immutableReferences"]
_names = ["token", "beneficiary", "releaseTime"]  # AST ids ascend in declaration order
assert len(_refs) == 3
main["__LOCK_ABI__"] = json.dumps(lk["abi"], separators=(",", ":"))
main["__LOCK_BC__"] = lk["bytecode"]["object"]
main["__LOCK_RT__"] = lk["deployedBytecode"]["object"]
main["__LOCK_IMM__"] = json.dumps({n: [r["start"] for r in _refs[k]] for n, k in zip(_names, sorted(_refs, key=int))}, separators=(",", ":"))
main["__LOCK_SHA__"] = hashlib.sha256(lk["bytecode"]["object"].encode()).hexdigest()
main["__UNLOCK__"] = "1825825200"
main["__LOCK_AMT__"] = "4500000"
# DustyLiquidityLock: Uniswap v3 position NFT #6525151 (USDC/DUSTY 1%) locked until the same unlock time; fees -> Stan
lp = art("DustyLiquidityLock")
_pr = lp["deployedBytecode"]["immutableReferences"]
assert len(_pr) == 4
main["__LP_ABI__"] = json.dumps(lp["abi"], separators=(",", ":"))
main["__LP_BC__"] = lp["bytecode"]["object"]
main["__LP_RT__"] = lp["deployedBytecode"]["object"]
main["__LP_IMM__"] = json.dumps({n: [r["start"] for r in _pr[k]] for n, k in zip(["positionManager", "tokenId", "beneficiary", "unlockTime"], sorted(_pr, key=int))}, separators=(",", ":"))
main["__LP_SHA__"] = hashlib.sha256(lp["bytecode"]["object"].encode()).hexdigest()
main["__LP_ID__"] = "6525151"
main["__POOL__"] = "0x4E74fFa1eb8d549a772673939946599246f854B3"
LOGO = "https://statxqo-clickit.github.io/dusty/token/dusty-256.png"
main["__LOGO_URL__"] = LOGO
sub["__LOGO_URL__"] = LOGO
import sys
_only = set(sys.argv[1:])  # optional: build only the named pages, e.g. `build-pages.py lock-reserve`
for name, subs in (("deploy", sub), ("recycler", sub), ("deploy-mainnet", main), ("seed-pool", main), ("treasury", main), ("lock-reserve", main), ("transparency", main)):
    if _only and name not in _only: continue
    s = (root / f"tools/{name}.tpl.html").read_text()
    for k, v in subs.items(): s = s.replace(k, v)
    import re as _re
    left = _re.findall(r"__[A-Z0-9_]+__", s)
    assert not left, (name, left)
    assert "__" + "TOKEN_BC__" not in s and "__" + "V3_" not in s and "__" + "USDC__" not in s
    (root / f"{name}.html").write_text(s)
    print(name + ".html", len(s), "bytes")
