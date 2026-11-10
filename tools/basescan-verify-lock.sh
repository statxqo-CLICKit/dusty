#!/usr/bin/env bash
# Verify DustyReserveLock on Basescan (Base mainnet 8453) after lock-reserve.html.
# Usage: ETHERSCAN_API_KEY=... tools/basescan-verify-lock.sh <LOCK_ADDRESS>
# Compiler: solc 0.8.24+commit.e11b9ed9, optimizer ON 200 runs, evmVersion cancun, viaIR off, OpenZeppelin 5.6.1, MIT.
# Constructor: (DUSTY 0xAf47E82C6f7cB9E28bB0382a1FeAdBC6308FDDc1, Reserve 0x4F9eb9a29c174Ec2a087545275Bf1e9070ef108C, 1825825200)
set -euo pipefail
LOCK=$1
: "${ETHERSCAN_API_KEY:?set ETHERSCAN_API_KEY (Etherscan v2 key works for Base)}"
ARGS=$(cast abi-encode "constructor(address,address,uint256)" 0xAf47E82C6f7cB9E28bB0382a1FeAdBC6308FDDc1 0x4F9eb9a29c174Ec2a087545275Bf1e9070ef108C 1825825200)
echo "DustyReserveLock constructor args: $ARGS"
forge verify-contract --chain 8453 --watch --compiler-version v0.8.24+commit.e11b9ed9 --num-of-optimizations 200 --evm-version cancun \
  --constructor-args "$ARGS" "$LOCK" contracts/DustyReserveLock.sol:DustyReserveLock
