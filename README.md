# ⛏️ ore-miner-skills — Mine $ORE on Solana with Your AI Agent

**The first OpenClaw / Clawdbot skill for autonomous crypto mining.** Your AI agent mines [$ORE](https://ore.supply) on Solana 24/7 via [refinORE](https://automine.refinore.com) — the only mining platform with full AI agent API support.

> Mine with SOL, USDC, ORE, or stablecoins. No hardware needed. Your agent handles everything.

[![OpenClaw Compatible](https://img.shields.io/badge/OpenClaw-Compatible-blue)](https://openclaw.com)
[![Solana](https://img.shields.io/badge/Solana-Powered-9945FF)](https://solana.com)
[![refinORE](https://img.shields.io/badge/refinORE-Agent%20API-00D4AA)](https://automine.refinore.com)

---

## 🚀 Quick Start (60 Seconds)

### For AI Agents (OpenClaw / Clawdbot)

Your agent already knows what to do. Just install the skill:

```bash
# Clone and install
git clone https://github.com/JussCubs/ore-miner-skills.git
cp -r ore-miner-skills/ore-miner ~/.openclaw/skills/
# or for Clawdbot:
cp -r ore-miner-skills/ore-miner ~/clawd/skills/
```

Then tell your agent: **"Set up ORE mining for me"** — it will walk you through everything.

### For Humans

1. **Create an account** at [automine.refinore.com](https://automine.refinore.com)
2. **Generate an API key** in Settings → API Keys
3. **Give the key to your agent** — set `REFINORE_API_KEY` in your agent's config
4. **Say "start mining"** — your agent takes it from there

---

## 🤖 What Your Agent Can Do

Once configured, your AI agent autonomously:

- **Mines ORE 24/7** — deploys SOL (or USDC/stablecoins) across the 5×5 mining grid
- **Optimizes strategy** — adjusts tiles, amounts, and timing based on EV (Expected Value)
- **Tracks P&L** — win rate, streaks, net profit in SOL and ORE
- **Manages risk** — stops on losing streaks, respects stop-losses
- **Hunts the Motherlode** — watches the accumulating jackpot (can reach 700+ ORE / $50K+)
- **Sets up DCA orders** — dollar-cost average into ORE automatically
- **Sets limit orders** — auto-swap at target prices
- **Manages staking** — stake ORE → stORE for ~22% APR
- **Reports everything** — sends updates on wins, losses, strategy changes

---

## 💰 Mine with Any Token

refinORE supports multi-token mining — your agent can mine using:

| Token | How It Works |
|-------|-------------|
| **SOL** | Deploy directly (default) |
| **USDC** | Auto-swap USDC → SOL for mining, SOL → USDC on claims |
| **ORE** | Compound — mine with ORE, earn more ORE |
| **stORE** | Staked ORE — mine while earning staking yield |

Perfect for stablecoin holders who want crypto mining exposure without holding volatile assets.

---

## 📦 What's Inside

```
ore-miner/
├── SKILL.md              # Complete agent instructions + onboarding flow
├── scripts/
│   ├── mine.sh           # Start/stop mining sessions
│   ├── check_round.sh    # Monitor current round (EV, motherlode)
│   ├── check_balance.sh  # Check wallet balances
│   ├── deploy.sh         # Deploy SOL to specific tiles
│   └── analytics.sh      # Pull mining stats and P&L
└── references/
    ├── api-endpoints.md  # Full refinORE API documentation
    ├── mining-rules.md   # ORE V2 mechanics, motherlode, EV
    └── strategies.md     # Tile strategies and when to use them
```

---

## ⚙️ Configuration

Set these in your agent's environment (`.env`, config file, or agent settings):

| Variable | Required | Description |
|----------|----------|-------------|
| `REFINORE_API_URL` | Yes | `https://automine.refinore.com/api` |
| `REFINORE_API_KEY` | Yes | Your API key from refinORE Settings |

That's it. Two variables. Your agent handles the rest.

---

## 🔗 Links

- **refinORE** — [automine.refinore.com](https://automine.refinore.com) — AI-powered ORE mining
- **ORE Protocol** — [ore.supply](https://ore.supply) — Solana proof-of-work mining
- **OpenClaw** — [openclaw.com](https://openclaw.com) — Open-source AI agent framework
- **Clawdbot** — [clawd.bot](https://clawd.bot) — Personal AI agent

---

## 🏷️ Keywords

`solana` `ore-mining` `openclaw` `clawdbot` `ai-agent` `crypto-mining` `usdc` `stablecoins` `defi` `proof-of-work` `autonomous-agent` `refinore`

---

MIT License
