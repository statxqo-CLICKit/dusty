# DUSTY listing steps (after the mainnet deploy)

Logos (GitHub Pages):
- 256×256 PNG (wallets, token list, Trust Wallet): https://statxqo-clickit.github.io/dusty/token/dusty-256.png
- 64×64 PNG (Basescan wants PNG 64×64 or SVG 32×32): https://statxqo-clickit.github.io/dusty/token/dusty-64.png
- 32×32 PNG (favicon-size): https://statxqo-clickit.github.io/dusty/token/dusty-32.png
- Ownership-proof signing page (personal_sign, no transactions): https://statxqo-clickit.github.io/dusty/sign-message.html
- 1024×1024 PNG (CoinGecko, press): https://statxqo-clickit.github.io/dusty/token/dusty-logo-1024.png

1. **Fill the address.** Replace `0x000…000` in `token/dusty.tokenlist.json` with the TOKEN_ADDRESS from deploy-mainnet.html, bump `timestamp`, push.
   List URL: https://statxqo-clickit.github.io/dusty/token/dusty.tokenlist.json (schema: https://uniswap.org/tokenlist.schema.json, https://tokenlists.org/).
2. **Basescan token info** (logo + links). Needs: source verified (`tools/basescan-verify.sh`), then ownership verified by signing with the deployer/admin wallet.
   - Guide: https://info.basescan.org/how-to-update-token-info/
   - Ownership: https://info.basescan.org/verifyaddress/
   - Form (log in first): https://basescan.org/tokenupdate · account: https://basescan.org/register
   - Upload the 64×64 PNG (dusty-64.png). Review takes time; paid expedite exists at https://basescan.org/priority-support (optional).
3. **Trust Wallet logo.** Not accepted for brand-new tokens: needs real circulation and holders first (https://developer.trustwallet.com/listing-new-assets/requirements).
   When eligible: https://assets.trustwallet.com (GitHub login) or a PR to https://github.com/trustwallet/assets under `blockchains/base/assets/<checksummed address>/` with `logo.png` (256×256, under 100 KB; dusty-256.png qualifies) + `info.json`.
4. **CoinGecko.** Requires active trading on a tracked exchange (Uniswap v3 Base pool counts) and a public verification post from an official account.
   - Guide: https://support.coingecko.com/hc/en-us/articles/7291312302617-How-to-List-a-New-Cryptocurrency-on-CoinGecko
   - Verification post: https://support.coingecko.com/hc/en-us/articles/23725417857817-Verification-Guide-for-Listing-Update-Requests-on-CoinGecko
   - Form (log in): https://partner.coingecko.com/request-form/new → New Coin/Token Listing. Link the pool's analytics page and upload the 1024 PNG. Listing is free.
