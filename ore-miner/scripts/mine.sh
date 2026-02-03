#!/bin/bash
# mine.sh — Start an ORE mining session via refinORE API
# Usage: mine.sh <api_url> <api_key> <sol_amount> <num_squares> <strategy>
# Example: mine.sh https://automine.refinore.com/api rsk_abc123 0.005 25 optimal
set -euo pipefail

API_URL="${1:?Usage: mine.sh <api_url> <api_key> <sol_amount> <num_squares> <strategy>}"
API_KEY="${2:?Missing API key}"
SOL_AMOUNT="${3:-0.005}"
NUM_SQUARES="${4:-25}"
STRATEGY="${5:-optimal}"

# Detect auth type: rsk_ prefix = API key, otherwise JWT
if [[ "$API_KEY" == rsk_* ]]; then
  AUTH_HEADER="x-api-key: $API_KEY"
else
  AUTH_HEADER="Authorization: Bearer $API_KEY"
fi

# Map strategy name to tile_selection_mode
case "$STRATEGY" in
  optimal)      TILE_MODE="optimal" ;;
  degen)        TILE_MODE="random"; NUM_SQUARES=25 ;;
  conservative) TILE_MODE="optimal" ;;
  random)       TILE_MODE="random" ;;
  *)            TILE_MODE="optimal" ;;
esac

# Map strategy to risk_tolerance
case "$STRATEGY" in
  degen)        RISK="high" ;;
  conservative) RISK="low" ;;
  *)            RISK="medium" ;;
esac

echo "⛏️ Starting mining session on refinORE..."
echo "  SOL per round: $SOL_AMOUNT"
echo "  Tiles: $NUM_SQUARES"
echo "  Strategy: $STRATEGY (mode=$TILE_MODE, risk=$RISK)"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/mining/start" \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d "{
    \"sol_amount\": $SOL_AMOUNT,
    \"num_squares\": $NUM_SQUARES,
    \"risk_tolerance\": \"$RISK\",
    \"mining_token\": \"SOL\",
    \"tile_selection_mode\": \"$TILE_MODE\",
    \"auto_restart\": true,
    \"frequency\": \"every_round\"
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
  echo "✅ Session started!"
  echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
else
  echo "❌ Failed (HTTP $HTTP_CODE)"
  echo "$BODY"
  exit 1
fi
