# Dusty mainnet checklist (Base, chainId 8453)

Nothing below has been done on mainnet yet. Stan signs every on-chain step in MetaMask; Hark never signs or sends.

## Values
| Item | Value |
|---|---|
| Admin / guardian / treasury (default) | Stan `0x9b8EBB1490E823bB152aCd64B198Df4d1035c7Fd` (move admin to a Safe later) |
| Quote signer (fresh mainnet key) | `0xE3ed6685AcB201EB40370d181766424C00F2515f` (key file only in Hark workspace `secrets/mainnet-signer.key`, chmod 600) |
| USDC (Circle, Base) | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| Fee | 500 bps (5%) |
| Admin delay | 172800 s (2 days), editable |
| Recycler mint budget | 100,000,000 DUSTY |
| Limits (contract defaults) | 10,000 DUSTY per quote, 1,000,000 DUSTY per rolling 24h |
| Uniswap v3 Factory (Base) | `0x33128a8fC17869897dcE68Ed026d694621f6FDfD` |
| Uniswap v3 NonfungiblePositionManager (Base) | `0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1` |
| Pool | DUSTY/USDC, fee tier 1% (10000), full range, start price $0.001 (1,000 DUSTY per $1); default seed 50 USDC + 50,000 DUSTY |

Uniswap addresses from https://docs.uniswap.org/contracts/v3/reference/deployments/base-deployments, checked with `eth_getCode` on mainnet.base.org (both have code; `NPM.factory()` returns the Factory).

## Order
**deploy contracts → seed pool → upload Worker with RECYCLER and POOL → flip LAUNCH_MODE**

## Steps
1. [ ] Stan has a little ETH on **Base** in `0x9b8E…c7fd` (≈ $1–3 covers the 4 deploy txs + up to 8 pool txs).
2. [ ] Stan opens **https://metamask.app.link/dapp/statxqo-clickit.github.io/dusty/deploy-mainnet.html**
       (desktop: https://statxqo-clickit.github.io/dusty/deploy-mainnet.html).
3. [ ] Connect → switches/adds Base → check the settings → tick both boxes → **Start deploy** → approve 4 transactions.
4. [ ] All 12 read-back checks show ✓ → **Copy config for Hark** → send to Hark.
5. [ ] **Seed the pool.** Stan needs the USDC to add (default 50) + a little ETH on Base in the admin wallet.
       Opens **https://metamask.app.link/dapp/statxqo-clickit.github.io/dusty/seed-pool.html**
       (desktop: https://statxqo-clickit.github.io/dusty/seed-pool.html). Same device as the deploy page fills the token address.
       Tick the box → **Start** → approve up to 8 transactions:
       setMinter(self, budget = seed amount) → mintReward(self) → setMinter(self, false, 0) → approve DUSTY → approve USDC →
       create pool at $0.001 → add full-range liquidity → turn on price history (200 observation slots).
       All read-back checks ✓ → **Copy pool config for Hark** → send to Hark.
       Resumable: tap again after any stop; finished steps are skipped. It refuses to add liquidity if the pool already exists at a price more than 2% from $0.001.
6. [ ] Hark uploads the mainnet Worker with the recycler **and** the pool:
       `CLOUDFLARE_API_TOKEN=… tools/upload-mainnet-worker.sh <RECYCLER_ADDRESS> <DUSTY_POOL>` → expect `unit tests: pass` and `HEALTH OK pricing: twap`
       (Worker `dusty-quote-mainnet`, URL `https://dusty-quote-mainnet.statxqo.workers.dev`).
       Pricing: dust in USD (USDC = $1; other tokens via DefiLlama) ÷ DUSTY price from the pool's **30-min TWAP**, contract takes 5%, capped at `maxDustyPerQuote`.
       The Worker **refuses quotes** (503) until the pool is 30 min old, and whenever spot is more than 20% away from the TWAP. Seed at least 30 min before launch.
       `/price` shows the current DUSTY price the Worker would use.
7. [ ] Cloudflare dashboard: add a rate-limit rule on `/quote` (e.g. 20 req/min per IP) (M-2).
8. [ ] Hark fills (flip LAUNCH_MODE last) `NETWORKS.mainnet.token` / `.recycler` in index.html, sets `LAUNCH_MODE = "mainnet"`, bumps sw cache, pushes.
9. [ ] Smoke test with $1 of USDC on Base: expect **≈950 DUSTY** at $0.001 (varies with the pool price) and a basescan.org tx link.
10. [ ] Verify both contracts on Basescan: `ETHERSCAN_API_KEY=… tools/basescan-verify.sh <TOKEN> <RECYCLER> <ADMIN> <GUARDIAN> <TREASURY> 0xE3ed6685AcB201EB40370d181766424C00F2515f 172800 500`
       (needs an Etherscan v2 API key).
11. [ ] Later: move admin to a Safe (two-step, delay applies), separate guardian and treasury wallets.

## Basescan verify inputs
- Compiler `v0.8.24+commit.e11b9ed9`, optimizer **on, 200 runs**, EVM **cancun**, viaIR **off**, license MIT, OpenZeppelin 5.6.1.
- Easiest: "Solidity (Standard-Json-Input)" with `audit/basescan-verify/DustyToken.standard-input.json` / `DustyRecycler.standard-input.json`
  (recompiled with solc 0.8.24: exact bytecode match with what deploy-mainnet.html deploys).
- Constructor args (ABI-encoded, no 0x on Basescan):
  - Token: `constructor(address admin, uint48 adminDelay, address guardian, uint256 initialSupply=0)`
    → `cast abi-encode "constructor(address,uint48,address,uint256)" <ADMIN> 172800 <GUARDIAN> 0`
  - Recycler: `constructor(address admin, uint48 adminDelay, address guardian, address dustyToken, address treasury, address quoteSigner, uint16 feeBps=500)`
    → `cast abi-encode "constructor(address,uint48,address,address,address,address,uint16)" <ADMIN> 172800 <GUARDIAN> <TOKEN> <TREASURY> 0xE3ed…515f 500`
  - With Stan's defaults the token args are:
    `0000000000000000000000009b8ebb1490e823bb152acd64b198df4d1035c7fd000000000000000000000000000000000000000000000000000000000002a3000000000000000000000000009b8ebb1490e823bb152acd64b198df4d1035c7fd0000000000000000000000000000000000000000000000000000000000000000`

## Open risks (unchanged)
Unaudited contracts; hot quote-signer key (bounded by caps); one wallet for admin/guardian/treasury until a Safe; ethers from CDN without SRI (M-4);
no Worker rate limit until the dashboard rule (M-2); remove raw.githack.com from the testnet Worker CORS list.
