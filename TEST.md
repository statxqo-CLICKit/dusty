# Dusty testnet v1 test (Base Sepolia)

The live app runs in `LAUNCH_MODE = "testnet"`: Base Sepolia, DUSTY token `0x297cBf5BB6CE735D879557E1099954569E246D43`,
Recycler v1 `0x199Fef502B969018091294a69e6634DA7aC9e64d`, quote service `https://dusty-quote.statxqo.workers.dev`.
Test tokens only. No real value.

**Before you start:** the test wallet already has **20 test USDC** and Base Sepolia ETH for gas.

1. On your phone, open **MetaMask** → **Browser** tab → go to `statxqo-clickit.github.io/dusty/`
   (or tap https://metamask.app.link/dapp/statxqo-clickit.github.io/dusty/).
2. You should see a small **"Base Sepolia test network"** badge under the progress dots. No other test/demo text.
3. Tap **Connect wallet** → **MetaMask** → approve.
4. Sign in (free) or tap **Skip for now**.
5. On the scan screen, if MetaMask is on another network a yellow banner shows **Switch to Base Sepolia**. Tap it and approve.
6. The list shows **USDC · Base Sepolia** ticked. In **Amount of USDC to recycle**, type **1**.
   "You'll receive" should read **950 DUSTY** (quote 1,000 DUSTY minus the 5% fee). Max per recycle is 9.99 USDC.
7. Tap **♻ Recycle dust**. MetaMask asks to **approve** the exact USDC amount, then to **confirm the recycle**.
8. Success screen: **+950 $DUSTY**, your new balance, and **View transaction on Basescan** opens
   `https://sepolia.basescan.org/tx/<hash>`.
9. Tap **Add $DUSTY to wallet** → approve → DUSTY shows in MetaMask on Base Sepolia.
10. Tap **Ask Dusty** (bottom right): every chip answers offline.

Pass = DUSTY received matches 95% of the quote, Basescan link opens the tx, no page errors.

Automated checks already run (local anvil, same bytecode): deploy-mainnet flow end to end (all 12 read-back checks pass, resume works);
mainnet Worker quote → recycle 1 USDC → **950.0 DUSTY**; index.html in mainnet mode: 9.99 USDC → **9,490.5 DUSTY**, then Amount=1 → **950 DUSTY**, success screen with basescan.org tx link.
