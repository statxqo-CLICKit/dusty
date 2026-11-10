#!/usr/bin/env bash
# Verify DustyLiquidityLock on Basescan (Base mainnet 8453) after lock-reserve.html step 1.
# Usage: ETHERSCAN_API_KEY=... tools/basescan-verify-liquidity-lock.sh <LP_LOCK_ADDRESS>
# Compiler: solc 0.8.24+commit.e11b9ed9, optimizer ON 200 runs, evmVersion cancun, viaIR off, OpenZeppelin 5.6.1, MIT.
# Constructor: (Uniswap v3 NonfungiblePositionManager 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1, tokenId 6525151,
#               beneficiary Stan 0x9b8EBB1490E823bB152aCd64B198Df4d1035c7Fd, unlockTime 1825825200)
set -euo pipefail
LOCK=$1
: "${ETHERSCAN_API_KEY:?set ETHERSCAN_API_KEY (Etherscan v2 key works for Base)}"
ARGS=$(cast abi-encode "constructor(address,uint256,address,uint256)" 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1 6525151 0x9b8EBB1490E823bB152aCd64B198Df4d1035c7Fd 1825825200)
echo "DustyLiquidityLock constructor args: $ARGS"
forge verify-contract --chain 8453 --watch --compiler-version v0.8.24+commit.e11b9ed9 --num-of-optimizations 200 --evm-version cancun \
  --constructor-args "$ARGS" "$LOCK" contracts/DustyLiquidityLock.sol:DustyLiquidityLock
