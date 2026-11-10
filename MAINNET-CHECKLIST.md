# Dusty mainnet checklist (Base, chainId 8453)

Nothing below has been done on mainnet yet. Stan signs every on-chain step in MetaMask; Hark never signs or sends.

## Values
| Item | Value |
|---|---|
| Admin / guardian (default) | Stan `0x9b8EBB1490E823bB152aCd64B198Df4d1035c7Fd` (move admin to a Safe later) |
| Treasury | 0xSplits v1 immutable 50/50 split `0x571E955471E93251d2a708Ea107eb86919639710` (Andrea `0x4eCDF3cA4BDc6Ee3257267384cf3915B49a585F2` 50% + Stan `0x9b8E…c7Fd` 50%, no controller). Created by the deploy page, step a. |
| 0xSplits SplitMain (Base) | `0x2ed6c4B5dA6378c7897AC67Ba9e43102Feb694EE` (SplitWallet impl `0xD94c0CE4f8eEfA4Ebf44bf6665688EdEEf213B33`), from https://docs.splits.org/core/split, code checked on mainnet.base.org |
| Multicall3 (Base) | `0xcA11bde05977b3631167028862bE2a173976CA11` (one-tap Distribute on treasury.html) |
| Dusty Rewards Reserve (publicly visible) | 5,000,000 DUSTY → `0x4F9eb9a29c174Ec2a087545275Bf1e9070ef108C` (Dusty Rewards Reserve). Editable on the deploy page; 0 skips it. |
| Quote signer (fresh mainnet key) | `0xE3ed6685AcB201EB40370d181766424C00F2515f` (key file only in Hark workspace `secrets/mainnet-signer.key`, chmod 600) |
| USDC (Circle, Base) | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| Fee | 500 bps (5%) |
| Admin delay | 172800 s (2 days), editable |
| Recycler mint budget | 100,000,000 DUSTY |
| Limits (contract defaults) | 10,000 DUSTY per quote, 1,000,000 DUSTY per rolling 24h |
| Uniswap v3 Factory (Base) | `0x33128a8fC17869897dcE68Ed026d694621f6FDfD` |
| Uniswap v3 NonfungiblePositionManager (Base) | `0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1` |
| Pool | DUSTY/USDC, fee tier 1% (10000), full range, start price **$0.0003** (≈3,333 DUSTY per $1); default seed **15 USDC + 50,000 DUSTY** |

Uniswap addresses from https://docs.uniswap.org/contracts/v3/reference/deployments/base-deployments, checked with `eth_getCode` on mainnet.base.org (both have code; `NPM.factory()` returns the Factory).

## Order
**deploy page (8 approvals) → seed pool (up to 8 approvals, by 21:00 PT) → wait 30 min for TWAP → upload Worker with RECYCLER and POOL → flip LAUNCH_MODE (target 21:47 PT)**

Approval counts Stan signs in MetaMask:
| Page | Approvals |
|---|---|
| deploy-mainnet.html | **8**: split, token, recycler, setMinter(recycler), allow USDC, setMinter(self, 5M), mint 5M to the Dusty Rewards Reserve, revoke self (5 if the Dusty Rewards Reserve amount is 0) |
| seed-pool.html | up to **8**: setMinter(self, seed), mint seed, revoke, approve DUSTY, approve USDC, create pool, add liquidity, price history |
| treasury.html | **1** per payout (Distribute fees → both wallets paid 50/50) |
| **Total to launch** | **16** (+1 each time fees are paid out) |

## Steps
1. [ ] Stan has a little ETH on **Base** in `0x9b8E…c7fd` (≈ $1–3 covers the 8 deploy txs + up to 8 pool txs).
2. [ ] Stan opens **https://metamask.app.link/dapp/statxqo-clickit.github.io/dusty/deploy-mainnet.html**
       (desktop: https://statxqo-clickit.github.io/dusty/deploy-mainnet.html).
3. [ ] Connect → switches/adds Base → check the settings (payout wallets, Dusty Rewards Reserve 5,000,000 → 0x4F9e…108C) → tick all three boxes → **Start deploy** → approve 8 transactions.
4. [ ] All 16 read-back checks show ✓ (split exists + immutable, treasury = split, Dusty Rewards Reserve holds its amount, your wallet cannot mint) → **Copy config for Hark** → send to Hark.
5. [ ] **Seed the pool.** Stan needs the USDC to add (default 15) + a little ETH on Base in the admin wallet.
       Opens **https://metamask.app.link/dapp/statxqo-clickit.github.io/dusty/seed-pool.html**
       (desktop: https://statxqo-clickit.github.io/dusty/seed-pool.html). Same device as the deploy page fills the token address.
       Tick the box → **Start** → approve up to 8 transactions:
       setMinter(self, budget = seed amount) → mintReward(self) → setMinter(self, false, 0) → approve DUSTY → approve USDC →
       create pool at $0.0003 → add full-range liquidity → turn on price history (200 observation slots).
       All read-back checks ✓ → **Copy pool config for Hark** → send to Hark.
       Resumable: tap again after any stop; finished steps are skipped. It refuses to add liquidity if the pool already exists at a price more than 2% from $0.0003.
6. [ ] Hark uploads the mainnet Worker with the recycler **and** the pool:
       `CLOUDFLARE_API_TOKEN=… tools/upload-mainnet-worker.sh <RECYCLER_ADDRESS> <DUSTY_POOL>` → expect `unit tests: pass` and `HEALTH OK pricing: twap`
       (Worker `dusty-quote-mainnet`, URL `https://dusty-quote-mainnet.statxqo.workers.dev`).
       Pricing: dust in USD (USDC = $1; other tokens via DefiLlama) ÷ DUSTY price from the pool's **30-min TWAP**, contract takes 5%, capped at `maxDustyPerQuote`.
       The Worker **refuses quotes** (503) until the pool is 30 min old, and whenever spot is more than 20% away from the TWAP. Seed at least 30 min before launch.
       At the $0.0003 start price, $1 of dust pays ≈3,333 DUSTY, ≈3,167 to the user after the 5% fee.
       The fixed rate (1,000 DUSTY per $1 = $0.001) is used **only when no DUSTY_POOL is configured**; it is not the launch rate.
       `/price` shows the current DUSTY price the Worker would use.
7. [ ] Cloudflare dashboard: add a rate-limit rule on `/quote` (e.g. 20 req/min per IP) (M-2).
8. [ ] Hark fills (flip LAUNCH_MODE last) `NETWORKS.mainnet.token` / `.recycler` in index.html, sets `LAUNCH_MODE = "mainnet"`, bumps sw cache, pushes.
9. [ ] Smoke test with $1 of USDC on Base: expect **≈3,167 DUSTY** at the $0.0003 pool price (varies as the pool trades) and a basescan.org tx link.
10. [ ] Verify both contracts on Basescan: `ETHERSCAN_API_KEY=… tools/basescan-verify.sh <TOKEN> <RECYCLER> <ADMIN> <GUARDIAN> 0x571E955471E93251d2a708Ea107eb86919639710 0xE3ed6685AcB201EB40370d181766424C00F2515f 172800 500`
       (needs an Etherscan v2 API key).
11. [ ] Fees: recycled dust collects in the split. Open **https://metamask.app.link/dapp/statxqo-clickit.github.io/dusty/treasury.html** → Connect → **Distribute fees** → 1 approval pays Stan and Andrea 50/50 (0xSplits keeps 1 unit per token for gas).
12. [ ] Token listing (logo, Basescan, Trust Wallet, CoinGecko): see `token/LISTING.md`.
13. [ ] Later: move admin to a Safe (two-step, delay applies) and a separate guardian wallet. Treasury is already the 50/50 split.

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

## Reserve lock (approved by Stan 2026-11-09)

- Contract: `contracts/DustyReserveLock.sol` (immutable, ownerless; releases only to the Reserve after the unlock time). Tests: `test/DustyReserveLock.t.sol` incl. Base fork test.
- Amount: 4,500,000 DUSTY locked; 500,000 DUSTY stay unlocked in the Dusty Rewards Reserve (rewards, listing costs).
- Unlock: `1825825200` = 2027-11-09 21:40 PST = 2027-11-10 05:40 UTC.
- [ ] Open https://statxqo-clickit.github.io/dusty/lock-reserve.html in MetaMask's browser and follow the one button (gas top-up from 0x9b8E → switch to Reserve → deploy lock → send 4.5M → read-back).
- [ ] Verify on Basescan: `ETHERSCAN_API_KEY=... tools/basescan-verify-lock.sh <LOCK_ADDRESS>`.
- Public page: https://statxqo-clickit.github.io/dusty/transparency.html (live from chain, finds the lock by itself).
