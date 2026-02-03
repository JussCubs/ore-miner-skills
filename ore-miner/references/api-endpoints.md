# refinORE API Endpoints

Base URL: `https://automine.refinore.com/api` (set via `REFINORE_API_URL`)

All authenticated endpoints require: `Authorization: Bearer <token>`

For comprehensive documentation with request/response examples, see [docs/API-REFERENCE.md](../../docs/API-REFERENCE.md).

---

## Mining Endpoints

### POST /mining/start
Start a new mining session.

**Request Body:**
```json
{
  "sol_amount": 0.01,
  "num_squares": 25,
  "risk_tolerance": "medium",
  "mining_token": "SOL",
  "tile_selection_mode": "optimal",
  "auto_restart": true,
  "frequency": "every_round"
}
```

**Parameters:**
| Field | Type | Description |
|-------|------|-------------|
| `sol_amount` | float | SOL to deploy per round (0.001–1.0) |
| `num_squares` | int | Number of tiles to cover (1–25) |
| `risk_tolerance` | string | `low`, `medium`, or `high` |
| `mining_token` | string | `SOL`, `USDC`, `ORE`, `stORE`, `SKR` |
| `tile_selection_mode` | string | `optimal` or `random` |
| `auto_restart` | bool | Auto-restart on next round |
| `frequency` | string | `every_round` |

**Response:** Session object with ID, status, config.

**Notes:**
- Only one session can be active at a time
- When `mining_token` ≠ SOL, backend auto-swaps to SOL pre-deploy and back post-claim
- `optimal` tile selection uses refinORE's AI model (historical data + ML predictions)

### POST /mining/start-strategy
Start mining with advanced strategy configuration.

**Request Body:** Same as `/mining/start` but supports:
```json
{
  "sol_amount": 0.01,
  "num_squares": 5,
  "tile_ids": [0, 6, 12, 18, 24],
  "risk_tolerance": "low",
  "mining_token": "SOL",
  "auto_restart": true,
  "frequency": "every_round"
}
```

Additional field: `tile_ids` (int[]) — specific tile IDs to deploy on (0–24).

### POST /mining/stop
Stop the active mining session.

**Response:** Confirmation with session summary.

### POST /mining/reload-session
Reload/restart the current session with existing config.

### GET /mining/session
Get the current active session status.

**Response:**
```json
{
  "id": "session_abc123",
  "status": "active",
  "config": {
    "sol_amount": 0.01,
    "num_squares": 25,
    "tile_selection_mode": "optimal",
    "mining_token": "SOL"
  },
  "rounds_played": 47,
  "rounds_won": 25,
  "total_deployed": 0.47,
  "total_won": 0.52,
  "net_pnl": 0.05,
  "ore_earned": 1.2,
  "started_at": "2026-02-01T12:00:00Z"
}
```

Returns `404` if no active session.

### GET /mining/session-rounds
Get round-by-round results for the current session.

**Response:**
```json
{
  "rounds": [
    {
      "round_number": 141092,
      "won": true,
      "sol_deployed": 0.01,
      "sol_earned": 0.0189,
      "ore_earned": 0.5,
      "tiles_selected": [1, 5, 12, 18, 24],
      "winning_tile": 12,
      "timestamp": "2026-02-01T12:01:31Z"
    }
  ]
}
```

### GET /mining/history
Get historical mining sessions.

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `limit` | int | 20 | Max sessions to return |

### GET /mining/last-config
Get the last mining configuration used. Essential for auto-restart.

### GET /mining/round/:roundNumber
Get details for a specific round by number.

---

## Round Endpoints

### GET /rounds/current
Get current active round information.

**Response:**
```json
{
  "round_number": 141093,
  "status": "active",
  "time_remaining": 45,
  "total_sol_deployed": 2.5,
  "num_miners": 89,
  "motherlode": 42.5,
  "ev_estimate": 12.3,
  "tiles": [
    {"id": 0, "sol_deployed": 0.12, "num_miners": 4},
    {"id": 1, "sol_deployed": 0.08, "num_miners": 3}
  ]
}
```

---

## Strategy Endpoints

### GET /api/auto-strategies
List all saved strategies.

**Response:**
```json
[
  {
    "id": "strat_123",
    "name": "My Conservative Strategy",
    "sol_amount": 0.005,
    "num_squares": 10,
    "tile_selection_mode": "optimal",
    "risk_tolerance": "low",
    "ev_threshold": 0,
    "motherlode_only": false,
    "auto_restart": true,
    "frequency": "every_round",
    "mining_token": "SOL"
  }
]
```

### POST /api/auto-strategies
Create a new strategy.

**Request Body:**
```json
{
  "name": "Degen ML Hunter",
  "sol_amount": 0.05,
  "num_squares": 25,
  "tile_selection_mode": "optimal",
  "risk_tolerance": "high",
  "ev_threshold": -5,
  "motherlode_only": false,
  "auto_restart": true,
  "frequency": "every_round",
  "mining_token": "SOL"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Human-readable strategy name |
| `ev_threshold` | float | Minimum EV% to deploy (skip rounds below) |
| `motherlode_only` | bool | Only mine when ML exceeds a threshold |

### PUT /api/auto-strategies/:id
Update an existing strategy. Partial updates supported.

### DELETE /api/auto-strategies/:id
Delete a saved strategy.

---

## Swap & Order Endpoints (DCA / Limit Orders)

### GET /api/auto-swap-orders
List active swap orders.

### POST /api/auto-swap-orders
Create a DCA or limit order.

**DCA Order:**
```json
{
  "type": "dca",
  "input_token": "SOL",
  "output_token": "ORE",
  "amount": 0.1,
  "interval_hours": 24,
  "total_orders": 30
}
```

**Limit Order:**
```json
{
  "type": "limit",
  "input_token": "SOL",
  "output_token": "ORE",
  "amount": 1.0,
  "target_price": 60.00,
  "direction": "buy"
}
```

### PUT /api/auto-swap-orders/:id
Update an existing order.

### DELETE /api/auto-swap-orders/:id
Cancel an active order.

---

## Staking Endpoints

### GET /api/staking/info
Get stake account info — stORE balance, APR, rewards earned.

**Response:**
```json
{
  "store_balance": 5.0,
  "ore_staked": 5.0,
  "apr": 22.1,
  "rewards_earned": 0.45,
  "auto_compound": true
}
```

---

## Tile Preset Endpoints

### GET /api/tile-presets
List saved tile presets.

### POST /api/tile-presets
Save a new tile preset.

**Request Body:**
```json
{
  "name": "Diagonal",
  "tile_ids": [0, 6, 12, 18, 24]
}
```

Tile IDs: 0–24 on the 5×5 grid.

---

## Wallet Endpoints

### GET /api/wallet/balance
Get all token balances.

**Response:**
```json
{
  "sol": 2.345,
  "ore": 12.7,
  "store": 5.0,
  "usdc": 50.0,
  "skr": 0.0
}
```

### GET /api/wallet/transactions
Get transaction history.

### POST /api/wallet/sign
Sign and send a transaction via Privy-managed wallet.

---

## SSE (Server-Sent Events)

### GET /api/sse
Real-time stream of mining events. More efficient than polling.

**Headers:**
```
Authorization: Bearer <token>
Accept: text/event-stream
```

**Events:**
| Event | Description |
|-------|-------------|
| `round_start` | New round began |
| `round_end` | Round completed with results |
| `deployment` | SOL deployed on tiles |
| `claim` | Rewards claimed |
| `balance_update` | Wallet balance changed |

**Example:**
```bash
curl -N "$REFINORE_API_URL/sse" \
  -H "Authorization: Bearer $REFINORE_AUTH_TOKEN" \
  -H "Accept: text/event-stream"
```

---

## Market & Public Endpoints

### GET /refinore-apr
Staking APR and market data. **No authentication required.**

**Response:**
```json
{
  "apr": 22.1,
  "ore_price": 75.50,
  "total_staked": 150000,
  "total_stakers": 4500
}
```

### GET /rewards
Mining rewards summary. **Auth required.**

### POST /coinbase-onramp
Generate Coinbase fiat onramp URL. **Auth required.**

**Response:**
```json
{
  "url": "https://pay.coinbase.com/...",
  "expires_at": "2026-02-01T13:00:00Z"
}
```

---

## User Endpoints

### GET /unsubscribe
Unsubscribe from email notifications.

### POST /resubscribe
Re-subscribe to email notifications.

---

## Chat Endpoints (ore.supply)

**Different base URL: `https://api.ore.supply`**

These are documented in the `ore-chat` skill. Key endpoints:

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/auth/login` | Authenticate with wallet signature |
| GET | `/chat/history` | Message history |
| POST | `/chat/send` | Send message |
| POST | `/chat/react` | React to message |
| POST | `/chat/typing/:pubkey` | Typing indicator |
| GET | `/users/:pubkey` | User profile |
| POST | `/users/:pubkey/username` | Set username (7-day cooldown) |

Reactions fallback URL: `https://ore-bsm.onrender.com`

---

## Error Handling

| HTTP Code | Meaning | Agent Action |
|-----------|---------|-------------|
| `200` | Success | Process response |
| `401` | Token expired | Pause mining, alert owner to re-auth |
| `404` | Not found (no session) | Handle gracefully |
| `429` | Rate limited | Back off, retry after delay |
| `500` | Server error | Retry after 30s, alert if persistent |
