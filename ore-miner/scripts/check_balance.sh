#!/bin/bash
# check_balance.sh — Check wallet balances on refinORE
# Usage: check_balance.sh <api_url> <api_key>
set -euo pipefail

API_URL="${1:-${REFINORE_API_URL:-https://automine.refinore.com/api}}"
API_KEY="${2:-${REFINORE_API_KEY:-${REFINORE_AUTH_TOKEN:-}}}"

if [ -z "$API_KEY" ]; then
  echo "❌ No credentials. Set REFINORE_API_KEY"; exit 1
fi

if [[ "$API_KEY" == rsk_* ]]; then
  AUTH_HEADER="x-api-key: $API_KEY"
else
  AUTH_HEADER="Authorization: Bearer $API_KEY"
fi

curl -s "$API_URL/wallet/balance" -H "$AUTH_HEADER" | python3 -m json.tool 2>/dev/null || \
  curl -s "$API_URL/wallet/balance" -H "$AUTH_HEADER"
