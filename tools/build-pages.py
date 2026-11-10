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
for name in ("deploy", "recycler"):
    s = (root / f"tools/{name}.tpl.html").read_text()
    for k, v in sub.items(): s = s.replace(k, v)
    (root / f"{name}.html").write_text(s)
    print(name + ".html", len(s), "bytes")
