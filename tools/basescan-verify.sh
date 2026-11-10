#!/usr/bin/env bash
# Verify Dusty v2 on Basescan (Base mainnet 8453) after deploy-mainnet.html.
# Usage: ETHERSCAN_API_KEY=... tools/basescan-verify.sh <TOKEN> <RECYCLER> <ADMIN> <GUARDIAN> <TREASURY> <SIGNER> [ADMIN_DELAY=172800] [FEE_BPS=500]
# Compiler: solc 0.8.24+commit.e11b9ed9, optimizer ON 200 runs, evmVersion cancun, viaIR off, OpenZeppelin 5.6.1, MIT.
# Standard-JSON inputs (exact bytecode match checked): audit/basescan-verify/*.standard-input.json
set -euo pipefail
TOKEN=$1 REC=$2 ADMIN=$3 GUARD=$4 TREAS=$5 SIGNER=$6 DELAY=${7:-172800} FEE=${8:-500}
: "${ETHERSCAN_API_KEY:?set ETHERSCAN_API_KEY (Etherscan v2 key works for Base)}"
TARGS=$(cast abi-encode "constructor(address,uint48,address,uint256)" "$ADMIN" "$DELAY" "$GUARD" 0)
RARGS=$(cast abi-encode "constructor(address,uint48,address,address,address,address,uint16)" "$ADMIN" "$DELAY" "$GUARD" "$TOKEN" "$TREAS" "$SIGNER" "$FEE")
echo "DustyToken constructor args:    $TARGS"
echo "DustyRecycler constructor args: $RARGS"
forge verify-contract --chain 8453 --watch --compiler-version v0.8.24+commit.e11b9ed9 --num-of-optimizations 200 --evm-version cancun \
  --constructor-args "$TARGS" "$TOKEN" contracts/DustyToken.sol:DustyToken
forge verify-contract --chain 8453 --watch --compiler-version v0.8.24+commit.e11b9ed9 --num-of-optimizations 200 --evm-version cancun \
  --constructor-args "$RARGS" "$REC" contracts/DustyRecycler.sol:DustyRecycler
