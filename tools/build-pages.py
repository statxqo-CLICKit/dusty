#!/usr/bin/env python3
"""Regenerate deploy.html and recycler.html from tools/*.tpl.html and the Foundry build in out/.
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
for name, subs in (("deploy", sub), ("recycler", sub), ("deploy-mainnet", main)):
    s = (root / f"tools/{name}.tpl.html").read_text()
    for k, v in subs.items(): s = s.replace(k, v)
    assert "__" + "TOKEN_BC__" not in s
    (root / f"{name}.html").write_text(s)
    print(name + ".html", len(s), "bytes")
