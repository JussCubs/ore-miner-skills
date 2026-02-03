#!/bin/bash
# auth_check.sh — Validate refinORE credentials
# Supports both API key (rsk_*) and legacy JWT
set -euo pipefail

API_URL="${REFINORE_API_URL:-https://automine.refinore.com/api}"
API_KEY="${REFINORE_API_KEY:-${REFINORE_AUTH_TOKEN:-}}"

if [ -z "$API_KEY" ]; then
  echo "❌ No credentials found. Set REFINORE_API_KEY or REFINORE_AUTH_TOKEN"
  exit 1
fi

# Detect auth type
if [[ "$API_KEY" == rsk_* ]]; then
  AUTH_HEADER="x-api-key: $API_KEY"
  echo "🔑 Using API key authentication"
else
  AUTH_HEADER="Authorization: Bearer $API_KEY"
  echo "🔑 Using JWT authentication (legacy)"
fi

RESPONSE=$(curl -s -w "\n%{http_code}" "$API_URL/wallet/balance" -H "$AUTH_HEADER")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
  echo "✅ Credentials valid!"
  echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
else
  echo "❌ Authentication failed (HTTP $HTTP_CODE)"
  echo "$BODY"
  exit 1
fi
