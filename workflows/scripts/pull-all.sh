#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKFLOWS_DIR="$ROOT_DIR/workflows"

# Load API key from .env
if [[ -f "$ROOT_DIR/.env" ]]; then
  export $(grep -v '^#' "$ROOT_DIR/.env" | xargs)
fi

if [[ -z "${N8N_API_KEY:-}" ]]; then
  echo "ERROR: N8N_API_KEY not set. Check your .env file." >&2
  exit 1
fi

BASE_URL="https://gosimple.app.n8n.cloud/api/v1"
PULLED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "Pulling active workflows from n8n..."
echo ""

# Get all active workflows
WORKFLOW_IDS=$(curl -sf \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  "$BASE_URL/workflows?active=true" \
  | python3 -c "import json,sys; [print(w['id']) for w in json.load(sys.stdin)['data']]")

COUNT=0
for WF_ID in $WORKFLOW_IDS; do
  # Fetch the full workflow
  RAW=$(curl -sf \
    -H "X-N8N-API-KEY: $N8N_API_KEY" \
    "$BASE_URL/workflows/$WF_ID")

  # Determine category from workflow name
  NAME=$(echo "$RAW" | python3 -c "import json,sys; print(json.load(sys.stdin)['name'])")

  if echo "$NAME" | grep -qi "multi-store\|blog.*v3"; then
    CATEGORY="shared"
  elif echo "$NAME" | grep -qi "junkireland\|junk ireland"; then
    CATEGORY="junkireland"
  else
    CATEGORY="glassbag"
  fi

  # Generate kebab-case filename from name
  FILENAME=$(echo "$NAME" | python3 -c "
import sys, re
name = sys.stdin.read().strip()
# Remove common prefixes
name = re.sub(r'^(NEW:|UPDATED:)\s*', '', name)
name = re.sub(r'^(Glassbag\.ie|GlassBag\.ie|JunkIreland\.ie)\s*[-:]\s*', '', name)
name = re.sub(r'^Blog ', '', name)
# Remove version suffixes and extra info in parens
name = re.sub(r'\s*\(.*?\)', '', name)
# Convert to kebab-case
name = re.sub(r'[^a-zA-Z0-9]+', '-', name).strip('-').lower()
# Remove trailing version numbers if already in name
name = re.sub(r'-+', '-', name)
print(name + '.json')
")

  mkdir -p "$WORKFLOWS_DIR/$CATEGORY"

  # Strip metadata, keep only essential fields + _meta
  echo "$RAW" | python3 -c "
import json, sys
data = json.load(sys.stdin)
clean = {
    '_meta': {
        'n8n_id': '$WF_ID',
        'pulled_at': '$PULLED_AT',
        'description': data.get('name', '')
    },
    'name': data.get('name', ''),
    'nodes': data.get('nodes', []),
    'connections': data.get('connections', {}),
    'settings': data.get('settings', {})
}
json.dump(clean, sys.stdout, indent=2)
" > "$WORKFLOWS_DIR/$CATEGORY/$FILENAME"

  NODE_COUNT=$(python3 -c "import json; print(len(json.load(open('$WORKFLOWS_DIR/$CATEGORY/$FILENAME'))['nodes']))")
  printf "  %-10s %-18s -> %s/%s (%s nodes)\n" "OK" "$WF_ID" "$CATEGORY" "$FILENAME" "$NODE_COUNT"
  COUNT=$((COUNT + 1))
done

echo ""
echo "Done! Pulled $COUNT workflows at $PULLED_AT"
