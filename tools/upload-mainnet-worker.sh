#!/usr/bin/env bash
# Upload the Dusty MAINNET quote Worker after deploy-mainnet.html has run.
# Usage: CLOUDFLARE_API_TOKEN=... tools/upload-mainnet-worker.sh <RECYCLER_V2_ADDRESS>
#   - Bundles workers/dusty-quote-mainnet.js with esbuild (--platform=browser, ESM).
#   - Uploads as Worker script "dusty-quote-mainnet" (separate from testnet "dusty-quote").
#   - Sets secret QUOTE_SIGNER_KEY_MAINNET from the key file (never printed) and var RECYCLER_V2.
#   - Enables workers.dev, then checks /health shows the expected signer + recycler.
set -euo pipefail
REC="${1:?usage: $0 <RECYCLER_V2_ADDRESS>}"
[[ "$REC" =~ ^0x[0-9a-fA-F]{40}$ ]] || { echo "bad recycler address"; exit 1; }
: "${CLOUDFLARE_API_TOKEN:?set CLOUDFLARE_API_TOKEN (from the vault)}"
ACCOUNT="${CF_ACCOUNT_ID:-1531fc8f5ef3475c2d4059445ab6ce65}"
NAME="${WORKER_NAME:-dusty-quote-mainnet}"
KEYFILE="${KEYFILE:-/workspace/projects/1f70029c-db9d-4eb4-8076-a31096ed8560/secrets/mainnet-signer.key}"
EXPECTED_SIGNER="0xE3ed6685AcB201EB40370d181766424C00F2515f"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ESBUILD="${ESBUILD:-/workspace/work/dusty-quote/node_modules/.bin/esbuild}"
NODE_PATH_DIR="${NODE_PATH_DIR:-/workspace/work/dusty-quote/node_modules}"
[ -f "$KEYFILE" ] || { echo "missing key file $KEYFILE"; exit 1; }
[ "$(stat -c %a "$KEYFILE")" = "600" ] || { echo "key file must be chmod 600"; exit 1; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cp "$ROOT/workers/dusty-quote-mainnet.js" "$TMP/worker.src.js"
ln -s "$NODE_PATH_DIR" "$TMP/node_modules"
"$ESBUILD" "$TMP/worker.src.js" --bundle --format=esm --platform=browser --minify --outfile="$TMP/worker.js" --log-level=warning
# metadata with secret built in python so the key never hits argv or stdout
python3 - "$TMP" "$REC" "$KEYFILE" <<'PY'
import json,sys
tmp,rec,kf=sys.argv[1:4]
key=open(kf).read().strip()
json.dump({"main_module":"worker.js","compatibility_date":"2026-11-01","bindings":[
  {"type":"plain_text","name":"RECYCLER_V2","text":rec},
  {"type":"secret_text","name":"QUOTE_SIGNER_KEY_MAINNET","text":key}]},open(tmp+"/meta.json","w"))
PY
chmod 600 "$TMP/meta.json"
API="https://api.cloudflare.com/client/v4/accounts/$ACCOUNT/workers/scripts/$NAME"
curl -fsS -X PUT "$API" -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -F "metadata=@$TMP/meta.json;type=application/json" -F "worker.js=@$TMP/worker.js;type=application/javascript+module" \
  | python3 -c "import json,sys;d=json.load(sys.stdin);print('upload success:',d.get('success'),d.get('errors'))"
curl -fsS -X POST "$API/subdomain" -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json" \
  -d '{"enabled":true}' | python3 -c "import json,sys;print('workers.dev enabled:',json.load(sys.stdin).get('success'))"
SUB="$(curl -fsS "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT/workers/subdomain" -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | python3 -c "import json,sys;print(json.load(sys.stdin)['result']['subdomain'])")"
URL="https://$NAME.$SUB.workers.dev"
echo "Worker URL: $URL"
for i in 1 2 3 4 5 6; do sleep 5; H="$(curl -fsS "$URL/health" || true)"; [ -n "$H" ] && break; done
echo "health: $H"
python3 - "$H" "$REC" "$EXPECTED_SIGNER" <<'PY'
import json,sys
h=json.loads(sys.argv[1] or "{}");rec,exp=sys.argv[2],sys.argv[3]
ok=h.get("ok") and h.get("chainId")==8453 and (h.get("signer") or "").lower()==exp.lower() and (h.get("recyclerV2") or "").lower()==rec.lower()
print("HEALTH OK" if ok else "HEALTH MISMATCH"); sys.exit(0 if ok else 2)
PY
