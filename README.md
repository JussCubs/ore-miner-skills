# ore-miner-skills

⛏️ OpenClaw/Clawdbot skill for autonomous ORE mining on Solana via refinORE.

AI agent handles onboarding, strategy, risk, P&L, DCA, staking — everything.

## Install

```bash
# Clone into your OpenClaw skills directory
git clone https://github.com/JussCubs/ore-miner-skills.git
```

**Other Options:**
- 🔨 **CLI Tool:** [refinore-cli](https://github.com/JussCubs/refinore-cli) — `npx -y refinore-cli --auto-mine`
- 🤖 **MCP Server:** [refinore-mcp](https://github.com/JussCubs/refinore-mcp) — For Cursor, Claude Desktop, Windsurf

## Contents

- `ore-miner/` — Full skill with SKILL.md, references, and scripts
  - `SKILL.md` — Main skill file (agent instructions)
  - `references/` — API endpoints, strategies, mining rules
  - `scripts/` — Bash scripts for mining operations

## API Endpoints Tested

All endpoints verified against live refinORE backend (Feb 4, 2026). See `ore-miner/references/api-endpoints.md` for full details.

## Links

- **refinORE:** [automine.refinore.com](https://automine.refinore.com)
- **OpenClaw:** [openclaw.ai](https://openclaw.ai)
