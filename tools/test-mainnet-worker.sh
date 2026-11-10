#!/usr/bin/env bash
# Unit tests for the mainnet quote Worker (node:test). Fork tests run too when FORK_* env is set:
#   FORK_RPC=http://127.0.0.1:8545 FORK_RECYCLER=0x.. FORK_POOL=0x.. FORK_USER=0x.. KEYFILE=<mainnet signer key file> tools/test-mainnet-worker.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NODE_PATH_DIR="${NODE_PATH_DIR:-/workspace/work/dusty-quote/node_modules}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/workers/test"; cp "$ROOT/workers/dusty-quote-mainnet.js" "$TMP/workers/"; cp "$ROOT/workers/test/dusty-quote-mainnet.test.mjs" "$TMP/workers/test/"
echo '{"type":"module"}' > "$TMP/package.json"; ln -s "$NODE_PATH_DIR" "$TMP/node_modules"
cd "$TMP" && node --test --test-reporter=spec workers/test/dusty-quote-mainnet.test.mjs
