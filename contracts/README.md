# DustyToken (DUSTY)

ERC-20, 1B max supply, owner + approved minters can mint rewards, holders can burn. Unaudited.

Deploy (Remix):
1. Open https://remix.ethereum.org, create DustyToken.sol, paste the file.
2. Compile with 0.8.24 or newer.
3. Deploy & Run → Environment "Injected Provider" (your wallet on Base Sepolia first).
4. Constructor: initialOwner = your wallet address, initialSupply = whole tokens (e.g. 0 or 100000000).
5. Verify on Basescan (flatten in Remix if needed).
6. Put the deployed address into TOKEN address in index.html.
