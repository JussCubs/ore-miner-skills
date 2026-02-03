#!/bin/bash
# deploy.sh — Start mining with specific tile IDs (advanced strategy)
# Usage: deploy.sh <api_url> <api_key> <sol_amount> <tile_ids_comma_separated>
# Example: deploy.sh https://automine.refinore.com/api rsk_abc 0.005 "0,1,2,3,4,5,10,15,20"
set -euo pipefail

API_URL="${1:?Usage: deploy.sh <api_url> <api_key> <sol_amount> <tile_ids>}"
API_KEY="${2:?Missing API key}"
SOL_AMOUNT="${3:-0.005}"
TILE_IDS="${4:?Missing tile IDs (comma-separated, 0-24)}"

if [[ "$API_KEY" == rsk_* ]]; then
  AUTH_HEADER="x-api-key: $API_KEY"
else
  AUTH_HEADER="Authorization: Bearer $API_KEY"
fi

# Convert comma-separated to JSON array
TILES_JSON=$(echo "$TILE_IDS" | python3 -c "import sys; print([int(x.strip()) for x in sys.stdin.read().split(',')])")
NUM_TILES=$(echo "$TILE_IDS" | tr ',' '\n' | wc -l)

echo "⛏️ Deploying with custom tiles on refinORE..."
echo "  SOL: $SOL_AMOUNT | Tiles: $NUM_TILES | IDs: $TILE_IDS"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/mining/start-strategy" \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d "{
    \"sol_amount\": $SOL_AMOUNT,
    \"num_squares\": $NUM_TILES,
    \"custom_tiles\": $TILES_JSON,
    \"mining_token\": \"SOL\",
    \"auto_restart\": true,
    \"frequency\": \"every_round\"
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
  echo "✅ Advanced strategy started!"
  echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
else
  echo "❌ Failed (HTTP $HTTP_CODE)"
  echo "$BODY"
  exit 1
fi
