#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load API key from .env
if [[ -f "$ROOT_DIR/.env" ]]; then
  export $(grep -v '^#' "$ROOT_DIR/.env" | xargs)
fi

if [[ -z "${N8N_API_KEY:-}" ]]; then
  echo "ERROR: N8N_API_KEY not set. Check your .env file." >&2
  exit 1
fi

if [[ -z "${1:-}" ]]; then
  echo "Usage: push.sh <workflow-json-file>" >&2
  echo "Example: push.sh workflows/glassbag/fulfil-shopify-orders.json" >&2
  exit 1
fi

FILE="$1"
if [[ ! -f "$FILE" ]]; then
  echo "ERROR: File not found: $FILE" >&2
  exit 1
fi

BASE_URL="https://gosimple.app.n8n.cloud/api/v1"

# Read n8n ID from _meta block
WF_ID=$(python3 -c "import json; print(json.load(open('$FILE'))['_meta']['n8n_id'])")
if [[ -z "$WF_ID" ]]; then
  echo "ERROR: No _meta.n8n_id found in $FILE" >&2
  exit 1
fi

echo "Pushing $FILE -> workflow $WF_ID"
echo ""

# Step 1: GET current live version (safety check)
echo "1. Fetching live version of $WF_ID..."
LIVE=$(curl -sf \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  "$BASE_URL/workflows/$WF_ID") || {
  echo "ERROR: Failed to fetch live workflow $WF_ID. Does it exist?" >&2
  exit 1
}

LIVE_NAME=$(echo "$LIVE" | python3 -c "import json,sys; print(json.load(sys.stdin)['name'])")
LIVE_NODES=$(echo "$LIVE" | python3 -c "import json,sys; print(len(json.load(sys.stdin)['nodes']))")
echo "   Live: \"$LIVE_NAME\" ($LIVE_NODES nodes)"

# Step 2: Build PUT payload from local file (only name, nodes, connections, settings)
LOCAL_NAME=$(python3 -c "import json; print(json.load(open('$FILE'))['name'])")
LOCAL_NODES=$(python3 -c "import json; print(len(json.load(open('$FILE'))['nodes']))")
echo "   Local: \"$LOCAL_NAME\" ($LOCAL_NODES nodes)"
echo ""

# Step 3: PUT the update
echo "2. Pushing update..."
PAYLOAD=$(python3 -c "
import json
data = json.load(open('$FILE'))
payload = {
    'name': data['name'],
    'nodes': data['nodes'],
    'connections': data['connections'],
    'settings': data.get('settings', {})
}
print(json.dumps(payload))
")

RESPONSE=$(curl -sf \
  -X PUT \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "$BASE_URL/workflows/$WF_ID") || {
  echo "ERROR: PUT request failed for workflow $WF_ID" >&2
  exit 1
}

# Step 4: Verify response
RESP_ID=$(echo "$RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
RESP_NODES=$(echo "$RESPONSE" | python3 -c "import json,sys; print(len(json.load(sys.stdin)['nodes']))")
RESP_NAME=$(echo "$RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin)['name'])")

echo ""
echo "3. Verification:"
if [[ "$RESP_ID" == "$WF_ID" ]]; then
  echo "   ID match: OK ($RESP_ID)"
else
  echo "   ID MISMATCH: expected $WF_ID, got $RESP_ID" >&2
  exit 1
fi

if [[ "$RESP_NODES" == "$LOCAL_NODES" ]]; then
  echo "   Node count match: OK ($RESP_NODES nodes)"
else
  echo "   WARNING: Node count mismatch - local=$LOCAL_NODES, remote=$RESP_NODES"
fi

echo "   Name: \"$RESP_NAME\""
echo ""
echo "Done! Workflow $WF_ID updated successfully."
