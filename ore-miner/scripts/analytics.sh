#!/bin/bash
# analytics.sh — Pull mining stats from refinORE API
# Usage: analytics.sh <command> <api_url> <api_key> [limit]
# Commands: history, pnl, round, apr
set -euo pipefail

CMD="${1:?Usage: analytics.sh <history|pnl|round|apr> <api_url> <api_key> [limit]}"
API_URL="${2:-${REFINORE_API_URL:-https://automine.refinore.com/api}}"
API_KEY="${3:-${REFINORE_API_KEY:-${REFINORE_AUTH_TOKEN:-}}}"
LIMIT="${4:-50}"

if [ -z "$API_KEY" ]; then
  echo "❌ No credentials. Set REFINORE_API_KEY"; exit 1
fi

if [[ "$API_KEY" == rsk_* ]]; then
  AUTH_HEADER="x-api-key: $API_KEY"
else
  AUTH_HEADER="Authorization: Bearer $API_KEY"
fi

case "$CMD" in
  history)
    echo "=== Mining History (last $LIMIT sessions) ==="
    curl -s "$API_URL/mining/history?limit=$LIMIT" -H "$AUTH_HEADER" | python3 -m json.tool
    ;;
  pnl)
    echo "=== Session P&L ==="
    curl -s "$API_URL/mining/session-rounds" -H "$AUTH_HEADER" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if not data: print('No active session'); sys.exit()
rounds = data if isinstance(data, list) else data.get('rounds', [])
wins = sum(1 for r in rounds if r.get('result') == 'win')
losses = len(rounds) - wins
print(f'Rounds: {len(rounds)} | Wins: {wins} | Losses: {losses} | Win Rate: {wins/max(len(rounds),1)*100:.1f}%')
"
    ;;
  round)
    echo "=== Current Round ==="
    curl -s "$API_URL/rounds/current" -H "$AUTH_HEADER" | python3 -m json.tool
    ;;
  apr)
    echo "=== Staking APR ==="
    curl -s "$API_URL/refinore-apr" | python3 -m json.tool
    ;;
  *)
    echo "Unknown command: $CMD (use: history, pnl, round, apr)"
    exit 1
    ;;
esac
