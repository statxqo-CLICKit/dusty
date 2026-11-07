// dusty-quote — signs Recycler quotes for Dusty (Base Sepolia TESTNET only).
// Secret required: QUOTE_SIGNER_KEY (private key of the Dusty Minter wallet), set by the owner in Cloudflare.
import { Wallet, JsonRpcProvider, Contract, getAddress } from "ethers";

const CHAIN_ID = 84532;
const RPC = "https://sepolia.base.org";
const RECYCLER = "0x199Fef502B969018091294a69e6634DA7aC9e64d";
const RATE = 1000n;            // testnet demo rate: DUSTY per $1
const MAX_USD = 10n;           // dust = under $10 per token
// Testnet tokens and their demo valuation (USD per whole token)
const TOKENS = {
  "0x036cbd53842c5426634e7929541ec2318f3dcf7e": { sym: "USDC", dec: 6, usd: 1n },
};
const ORIGINS = ["https://statxqo-clickit.github.io"];
const TYPES = { Quote: [
  { name: "user", type: "address" }, { name: "token", type: "address" }, { name: "amount", type: "uint256" },
  { name: "dustyOut", type: "uint256" }, { name: "nonce", type: "uint256" }, { name: "deadline", type: "uint256" } ] };

function cors(req) {
  const o = req.headers.get("Origin") || "";
  return { "Access-Control-Allow-Origin": ORIGINS.includes(o) ? o : ORIGINS[0], "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type", "Vary": "Origin", "Content-Type": "application/json" };
}
const json = (req, body, status = 200) => new Response(JSON.stringify(body), { status, headers: cors(req) });

export default {
  async fetch(req, env) {
    if (req.method === "OPTIONS") return new Response(null, { headers: cors(req) });
    const url = new URL(req.url);
    const signer = env.QUOTE_SIGNER_KEY ? new Wallet(env.QUOTE_SIGNER_KEY) : null;
    if (url.pathname === "/health")
      return json(req, { ok: !!signer, signer: signer ? signer.address : null, recycler: RECYCLER, chainId: CHAIN_ID, testnet: true });
    if (url.pathname !== "/quote" || req.method !== "POST") return json(req, { error: "not found" }, 404);
    if (!signer) return json(req, { error: "signer not configured" }, 503);
    let b; try { b = await req.json(); } catch { return json(req, { error: "bad json" }, 400); }
    let user, token, amount;
    try { user = getAddress(b.user); token = getAddress(b.token); amount = BigInt(b.amount); } catch { return json(req, { error: "bad params" }, 400); }
    const t = TOKENS[token.toLowerCase()];
    if (!t) return json(req, { error: "token not supported on testnet" }, 400);
    if (amount <= 0n) return json(req, { error: "zero amount" }, 400);
    const unit = 10n ** BigInt(t.dec);
    if (amount * t.usd >= MAX_USD * unit) return json(req, { error: "not dust (over $10)" }, 400);
    const dustyOut = (amount * t.usd * RATE * 10n ** 18n) / unit;
    const provider = new JsonRpcProvider(RPC, CHAIN_ID, { staticNetwork: true });
    const rec = new Contract(RECYCLER, ["function nonces(address) view returns (uint256)", "function feeBps() view returns (uint16)"], provider);
    const [nonce, feeBps] = await Promise.all([rec.nonces(user), rec.feeBps()]);
    const deadline = BigInt(Math.floor(Date.now() / 1000) + 600);
    const domain = { name: "DustyRecycler", version: "1", chainId: CHAIN_ID, verifyingContract: RECYCLER };
    const value = { user, token, amount, dustyOut, nonce, deadline };
    const signature = await signer.signTypedData(domain, TYPES, value);
    const fee = (dustyOut * BigInt(feeBps)) / 10000n;
    return json(req, { user, token, amount: amount.toString(), dustyOut: dustyOut.toString(), toUser: (dustyOut - fee).toString(),
      fee: fee.toString(), feeBps: Number(feeBps), nonce: nonce.toString(), deadline: deadline.toString(), signature, recycler: RECYCLER, chainId: CHAIN_ID, testnet: true });
  },
};
