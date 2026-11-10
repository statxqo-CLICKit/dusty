// Unit tests for workers/dusty-quote-mainnet.js. Run: tools/test-mainnet-worker.sh
// Fork tests (optional) run when FORK_RPC, FORK_RECYCLER, FORK_POOL, FORK_USER and KEYFILE are set (see tools/test-mainnet-worker.sh).
import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { ethers } from "ethers";
import W, { twapTick, tickToUsdPerDusty, deviationBps, payout, toE18, twapSeconds, priceDust, priceDusty, QuoteError,
  FIXED_PRICE_1E18, USDC, E18 } from "../dusty-quote-mainnet.js";

const req = (path, body, method = body ? "POST" : "GET") => new Request("https://w.example" + path,
  { method, headers: { "Content-Type": "application/json", Origin: "https://statxqo-clickit.github.io" }, body: body ? JSON.stringify(body) : undefined });

test("twapTick rounds toward -infinity like OracleLibrary", () => {
  assert.equal(twapTick(0n, 1800n * 100n, 1800), 100);
  assert.equal(twapTick(0n, -1800n * 100n, 1800), -100);
  assert.equal(twapTick(0n, -1801n, 1800), -2);
  assert.equal(twapTick(0n, 1801n, 1800), 1);
  assert.equal(twapTick(1000n, 1000n, 1800), 0);
});

test("tick → USD per DUSTY for both token orders (18 vs 6 decimals)", () => {
  // $0.001: DUSTY token0 → tick ≈ -345405/-345406; USDC token0 → tick ≈ +345405
  assert.ok(Math.abs(tickToUsdPerDusty(-345406, true) / 0.001 - 1) < 2e-4);
  assert.ok(Math.abs(tickToUsdPerDusty(345405, false) / 0.001 - 1) < 2e-4);
  // $1: DUSTY token0 → raw price 1e-12 → tick ≈ -276324
  assert.ok(Math.abs(tickToUsdPerDusty(-276324, true) - 1) < 1e-4);
});

test("deviation in bps between ticks", () => {
  assert.equal(deviationBps(100, 100), 0);
  assert.ok(Math.abs(deviationBps(1823, 0) - 2000) <= 2);   // 1.0001^1823 ≈ 1.20
  assert.ok(deviationBps(2300, 0) > 2000);
  assert.ok(deviationBps(-2300, 0) > 2000);
  assert.ok(deviationBps(-1000, 0) < 2000);
});

test("payout: $1 at $0.001 = 1000 DUSTY (950 after the contract's 5% fee)", () => {
  const { dustyOut, capped } = payout(1n * E18, FIXED_PRICE_1E18, 10_000n * E18);
  assert.equal(dustyOut, 1000n * E18); assert.equal(capped, false);
  assert.equal(dustyOut - (dustyOut * 500n) / 10000n, 950n * E18);
});
test("payout: market price halves → twice the DUSTY", () => {
  assert.equal(payout(E18, FIXED_PRICE_1E18 / 2n, null).dustyOut, 2000n * E18);
});
test("payout: capped at the per-quote limit", () => {
  const r = payout(9n * E18, 10n ** 14n, 10_000n * E18); // $9 at $0.0001 = 90,000 → capped
  assert.equal(r.dustyOut, 10_000n * E18); assert.equal(r.capped, true);
});
test("payout: zero price refused", () => { assert.throws(() => payout(E18, 0n, null), QuoteError); });
test("toE18 rejects NaN/0/inf", () => { for (const x of [0, NaN, Infinity, -1]) assert.throws(() => toE18(x)); assert.equal(toE18(0.001), 10n ** 15n); });
test("TWAP window: default 1800, bounded 600-3600", () => {
  assert.equal(twapSeconds({}), 1800); assert.equal(twapSeconds({ TWAP_SECONDS: "900" }), 900);
  assert.equal(twapSeconds({ TWAP_SECONDS: "60" }), 1800); assert.equal(twapSeconds({ TWAP_SECONDS: "x" }), 1800);
});

const WETH = "0x4200000000000000000000000000000000000006";
const llama = (o, ok = true) => async () => ({ ok, json: async () => ({ coins: o }) });
test("dust price: USDC is fixed $1, no API call", async () => {
  const r = await priceDust(USDC, 2_500_000n, 6, () => { throw new Error("should not fetch"); });
  assert.equal(r.usd1e18, 25n * 10n ** 17n);
});
test("dust price: DefiLlama for other tokens", async () => {
  const now = Math.floor(Date.now() / 1000);
  const r = await priceDust(WETH, 10n ** 15n, 18, llama({ ["base:" + WETH]: { price: 2000, confidence: 0.99, timestamp: now } }));
  assert.equal(r.usd1e18, 2n * E18); assert.equal(r.source, "defillama");
});
test("dust price: refuses stale, low-confidence, missing, HTTP error", async () => {
  const now = Math.floor(Date.now() / 1000);
  await assert.rejects(priceDust(WETH, 1n, 18, llama({ ["base:" + WETH]: { price: 2000, confidence: 0.99, timestamp: now - 7200 } })), /stale/);
  await assert.rejects(priceDust(WETH, 1n, 18, llama({ ["base:" + WETH]: { price: 2000, confidence: 0.5, timestamp: now } })), /not reliable/);
  await assert.rejects(priceDust(WETH, 1n, 18, llama({})), /unavailable/);
  await assert.rejects(priceDust(WETH, 1n, 18, llama({}, false)), /unavailable/);
});
test("DUSTY price: no pool configured → fixed $0.001", async () => {
  assert.equal((await priceDusty(null, null, WETH, 1800)).price1e18, FIXED_PRICE_1E18);
});
test("health: fails closed without key, reports pricing mode", async () => {
  let h = await (await W.fetch(req("/health"), {})).json();
  assert.equal(h.ok, false); assert.equal(h.pricing, "fixed");
  h = await (await W.fetch(req("/health"), { DUSTY_POOL: "nope" })).json(); assert.equal(h.pricing, "bad-pool");
  const r = await W.fetch(req("/quote", { user: WETH, token: USDC, amount: "1" }), { DUSTY_POOL: "nope" }); assert.equal(r.status, 503);
});

// ---------------- fork tests ----------------
const F = process.env;
const fork = F.FORK_RPC && F.FORK_RECYCLER && F.FORK_POOL && F.FORK_USER && F.KEYFILE && fs.existsSync(F.KEYFILE);
test("fork: TWAP/quote/deviation against the seeded DUSTY/USDC pool", { skip: (!fork || F.FORK_AFTER_SWAP) && "set FORK_* env to run (and not FORK_AFTER_SWAP)" }, async () => {
  const key = fs.readFileSync(F.KEYFILE, "utf8").trim();
  const env = { QUOTE_SIGNER_KEY_MAINNET: key, RECYCLER_V2: F.FORK_RECYCLER, DUSTY_POOL: F.FORK_POOL, RPC_URL: F.FORK_RPC };
  const rpc = (m, p = []) => fetch(F.FORK_RPC, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: m, params: p }) }).then(r => r.json());
  const quote = async (e) => { const r = await W.fetch(req("/quote", { user: F.FORK_USER, token: USDC, amount: "1000000" }), e); return { status: r.status, j: await r.json() }; };
  let q = await quote(env);
  console.log("  fresh pool (<30 min old):", q.status, q.j.error);
  if (q.status === 503) assert.match(q.j.error, /TWAP not ready/);
  await rpc("evm_increaseTime", [1900]); await rpc("evm_mine");
  q = await quote(env);
  console.log("  after 30 min:", q.status, "dustyOut", q.j.dustyOut && ethers.formatUnits(q.j.dustyOut, 18), "toUser", q.j.toUser && ethers.formatUnits(q.j.toUser, 18), JSON.stringify(q.j.pricing));
  assert.equal(q.status, 200);
  const out = Number(ethers.formatUnits(q.j.dustyOut, 18));
  assert.ok(Math.abs(out - 1000) < 1, "≈1000 DUSTY for $1 at $0.001");
  assert.equal(q.j.pricing.source, "twap");
  fs.writeFileSync(F.QUOTE_OUT || "/tmp/quote.json", JSON.stringify(q.j));
  const p = await (await W.fetch(req("/price"), env)).json();
  console.log("  /price:", JSON.stringify(p));
  // no pool → fixed fallback
  const { DUSTY_POOL, ...noPool } = env;
  q = await quote(noPool); assert.equal(q.status, 200); assert.equal(q.j.dustyOut, (1000n * E18).toString()); assert.equal(q.j.pricing.source, "fixed");
  // pool that is not DUSTY/USDC → refuse
  q = await quote({ ...env, DUSTY_POOL: "0xd0b53D9277642d899DF5C87A3966A349A798F224" }); // WETH/USDC 0.05% v3 on Base
  console.log("  wrong pool:", q.status, q.j.error); assert.equal(q.status, 503);
});
test("fork: spot moves >20% vs TWAP → refuse", { skip: !(fork && F.FORK_AFTER_SWAP) && "set FORK_AFTER_SWAP after a big swap" }, async () => {
  const key = fs.readFileSync(F.KEYFILE, "utf8").trim();
  const env = { QUOTE_SIGNER_KEY_MAINNET: key, RECYCLER_V2: F.FORK_RECYCLER, DUSTY_POOL: F.FORK_POOL, RPC_URL: F.FORK_RPC };
  const r = await W.fetch(req("/quote", { user: F.FORK_USER, token: USDC, amount: "1000000" }), env); const j = await r.json();
  console.log("  after big swap:", r.status, j.error); assert.equal(r.status, 503); assert.match(j.error, /moving too fast/);
});
