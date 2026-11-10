// dusty-quote — signs Recycler quotes for Dusty (Base Sepolia TESTNET only).
//
// v2 (security-fixes branch):
//   * Serves BOTH the legacy v1 recycler (current live app) and the v2 recycler.
//     v2 address comes from the Worker variable RECYCLER_V2 (set it after deploying v2).
//     The client sends {recycler} in the /quote body; missing = legacy v1.
//   * v2 quotes include feeBps in the signed data and use EIP-712 domain version "2".
//   * Signer key: secret QUOTE_SIGNER_KEY. The old "generate a key and keep it in KV" fallback is REMOVED
//     (fail closed, M-3). A key already stored in KV is still read so the live demo keeps working; move it
//     into the QUOTE_SIGNER_KEY secret and delete it from KV.
//   * Checks the user actually holds the dust before signing; RPC errors return JSON 502 with CORS (M-2, L-5).
//   * Rate limiting / Turnstile must be configured in the Cloudflare dashboard (not in code).
import { Wallet, JsonRpcProvider, Contract, getAddress } from "ethers";

const CHAIN_ID = 84532;
const RPC = "https://sepolia.base.org";
const RECYCLER_V1 = "0x199Fef502B969018091294a69e6634DA7aC9e64d";
const RATE = 1000n;            // testnet demo rate: DUSTY per $1
const MAX_USD = 10n;           // dust = under $10 per token (10,000 DUSTY max, = v2 on-chain maxDustyPerQuote default)
const QUOTE_TTL = 600;         // seconds (v2 contract hard limit is 900)
// Testnet tokens and their demo valuation (USD per whole token). Must match the v2 on-chain allowlist.
const TOKENS = {
  "0x036cbd53842c5426634e7929541ec2318f3dcf7e": { sym: "USDC", dec: 6, usd: 1n },
};
// raw.githack.com = preview of the security-fixes branch for testing only. Remove before mainnet.
const ORIGINS = ["https://statxqo-clickit.github.io", "https://raw.githack.com"];
const TYPES_V1 = { Quote: [
  { name: "user", type: "address" }, { name: "token", type: "address" }, { name: "amount", type: "uint256" },
  { name: "dustyOut", type: "uint256" }, { name: "nonce", type: "uint256" }, { name: "deadline", type: "uint256" } ] };
const TYPES_V2 = { Quote: [
  { name: "user", type: "address" }, { name: "token", type: "address" }, { name: "amount", type: "uint256" },
  { name: "dustyOut", type: "uint256" }, { name: "feeBps", type: "uint16" }, { name: "nonce", type: "uint256" },
  { name: "deadline", type: "uint256" } ] };

function cors(req) {
  const o = req.headers.get("Origin") || "";
  return { "Access-Control-Allow-Origin": ORIGINS.includes(o) ? o : ORIGINS[0], "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type", "Vary": "Origin", "Content-Type": "application/json" };
}
const json = (req, body, status = 200) => new Response(JSON.stringify(body), { status, headers: cors(req) });

async function loadSigner(env) {
  if (env.QUOTE_SIGNER_KEY) return { signer: new Wallet(env.QUOTE_SIGNER_KEY), legacyKv: false };
  if (env.DUSTY_KV) {
    const k = await env.DUSTY_KV.get("signer_key"); // legacy only: never generates a new key
    if (k) return { signer: new Wallet(k), legacyKv: true };
  }
  return { signer: null, legacyKv: false };
}

export default {
  async fetch(req, env) {
    if (req.method === "OPTIONS") return new Response(null, { headers: cors(req) });
    const url = new URL(req.url);
    const { signer, legacyKv } = await loadSigner(env);
    let v2 = null;
    try { if (env.RECYCLER_V2) v2 = getAddress(env.RECYCLER_V2); } catch { v2 = null; }

    if (url.pathname === "/health")
      return json(req, { ok: !!signer, signer: signer ? signer.address : null, recycler: RECYCLER_V1, recyclerV2: v2,
        chainId: CHAIN_ID, testnet: true, legacyKvKey: legacyKv });
    if (url.pathname !== "/quote" || req.method !== "POST") return json(req, { error: "not found" }, 404);
    if (!signer) return json(req, { error: "signer not configured" }, 503);

    let b; try { b = await req.json(); } catch { return json(req, { error: "bad json" }, 400); }
    let user, token, amount, recycler;
    try {
      user = getAddress(b.user); token = getAddress(b.token); amount = BigInt(b.amount);
      recycler = b.recycler ? getAddress(b.recycler) : RECYCLER_V1;
    } catch { return json(req, { error: "bad params" }, 400); }
    const isV2 = v2 !== null && recycler === v2;
    if (!isV2 && recycler !== RECYCLER_V1) return json(req, { error: "unknown recycler" }, 400);
    const t = TOKENS[token.toLowerCase()];
    if (!t) return json(req, { error: "token not supported on testnet" }, 400);
    if (amount <= 0n) return json(req, { error: "zero amount" }, 400);
    const unit = 10n ** BigInt(t.dec);
    if (amount * t.usd >= MAX_USD * unit) return json(req, { error: "not dust (over $10)" }, 400);
    const dustyOut = (amount * t.usd * RATE * 10n ** 18n) / unit;

    let nonce, feeBps;
    try {
      const provider = new JsonRpcProvider(RPC, CHAIN_ID, { staticNetwork: true });
      const rec = new Contract(recycler, ["function nonces(address) view returns (uint256)", "function feeBps() view returns (uint16)"], provider);
      const erc = new Contract(token, ["function balanceOf(address) view returns (uint256)"], provider);
      let bal;
      [nonce, feeBps, bal] = await Promise.all([rec.nonces(user, { blockTag: "latest" }), rec.feeBps(), erc.balanceOf(user)]);
      if (bal < amount) return json(req, { error: "insufficient balance" }, 400);
    } catch (e) {
      return json(req, { error: "rpc unavailable, try again" }, 502);
    }

    const deadline = BigInt(Math.floor(Date.now() / 1000) + QUOTE_TTL);
    const domain = { name: "DustyRecycler", version: isV2 ? "2" : "1", chainId: CHAIN_ID, verifyingContract: recycler };
    const signature = isV2
      ? await signer.signTypedData(domain, TYPES_V2, { user, token, amount, dustyOut, feeBps: Number(feeBps), nonce, deadline })
      : await signer.signTypedData(domain, TYPES_V1, { user, token, amount, dustyOut, nonce, deadline });
    const fee = (dustyOut * BigInt(feeBps)) / 10000n;
    return json(req, { user, token, amount: amount.toString(), dustyOut: dustyOut.toString(), toUser: (dustyOut - fee).toString(),
      fee: fee.toString(), feeBps: Number(feeBps), nonce: nonce.toString(), deadline: deadline.toString(), signature,
      recycler, version: isV2 ? 2 : 1, chainId: CHAIN_ID, testnet: true });
  },
};
