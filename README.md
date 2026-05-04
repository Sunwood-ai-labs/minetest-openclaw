# minetest-openclaw

OpenClaw agents living in a Minetest world. Inspired by [ONI-CADIA](https://github.com/Sunwood-ai-labs/ONI-CADIA).

## Architecture

```
┌──────────────────────────────────────────────────┐
│                  Podman / Docker                  │
│                                                   │
│  ┌──────────────┐     ┌──────────────┐           │
│  │  Minetest     │     │  Bridge      │           │
│  │  Server       │<───>│  (Node.js)   │           │
│  │  Port: 30000  │HTTP │  Port: 8080  │           │
│  │  + openclaw_  │poll │  REST API    │           │
│  │    bot mod    │     └──────┬───────┘           │
│  └──────────────┘            │                    │
│                              │ REST API           │
│  ┌───────────────────────────┼───────────────┐    │
│  │  OpenClaw Agents          │               │    │
│  │  ┌─────────┐ ┌─────────┐ │ ┌─────────┐  │    │
│  │  │  iori   │ │ tsumugi │ │ │  saku   │  │    │
│  │  │Architect│ │Creative │ │ │Inspector│  │    │
│  │  └─────────┘ └─────────┘ │ └─────────┘  │    │
│  │  Each has: SOUL.md, IDENTITY.md, etc.     │    │
│  └───────────────────────────────────────────┘    │
└──────────────────────────────────────────────────┘

         Human Player
         (Minetest Client)
              │
              └──> localhost:30000
```

## Prerequisites

- macOS with [Podman](https://podman.io)
- [Minetest](https://www.minetest.net) client (free, open source)
- Node.js 22+ (for bridge development)

### Install dependencies

```bash
# Podman
brew install podman
podman machine init
podman machine start

# podman-compose (optional, docker-compose works too)
pip3 install podman-compose

# Minetest client
brew install --cask minetest
```

## Quick Start

```bash
cd ~/Prj/minetest-openclaw

# 1. Initialize
./scripts/init.sh

# 2. Start servers
./scripts/launch.sh

# 3. Open Minetest client
#    Address: localhost
#    Port: 30000
#    (No account needed for local server)

# 4. Test the bridge
./scripts/test-bridge.sh
```

## Using with OpenClaw

Each agent workspace follows the ONI-CADIA pattern:

```
agents/instances/<agent_id>/
├── IDENTITY.md    # Who this citizen is
├── SOUL.md        # Shared civic values (from templates/)
├── HEARTBEAT.md   # What to do on each tick
├── TOOLS.md       # How to use the mineworld tools
└── BOOTSTRAP.md   # First-run orientation
```

To run an OpenClaw agent that controls a character in Minetest:

```bash
# Install OpenClaw
npm install -g openclaw@latest

# Create a workspace for your agent
mkdir -p ~/.openclaw/workspace
cp -r agents/templates/* ~/.openclaw/workspace/
cp agents/instances/iori/IDENTITY.md ~/.openclaw/workspace/
cp -r openclaw-skill/mineworld ~/.openclaw/workspace/skills/mineworld

# Edit the skill to set your agent ID
# Replace {{AGENT_ID}} with "iori" in SKILL.md

# Start OpenClaw
openclaw onboard
openclaw agent --message "You are iori. Look around your world and start building."
```

## Bridge API

The bridge at `http://localhost:8080/api` connects OpenClaw to Minetest.

### For OpenClaw Agents

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/agents` | Register a new agent |
| GET | `/api/agents` | List all agents and states |
| GET | `/api/state/:id` | Get agent's current position |
| POST | `/api/command/:id` | Queue a command for agent |
| POST | `/api/do/:id/:action` | Shortcut: queue action directly |
| GET | `/api/look/:id` | Get last look results |
| GET | `/api/health` | Bridge health check |

### Commands

```json
{"action": "move", "target": {"x": 10, "y": 5, "z": 20}}
{"action": "teleport", "target": {"x": 0, "y": 10, "z": 0}}
{"action": "dig", "pos": {"x": 10, "y": 5, "z": 20}}
{"action": "place", "pos": {"x": 10, "y": 6, "z": 20}, "node": "default:stone"}
{"action": "chat", "message": "Hello!"}
{"action": "look"}
```

## Default Citizens

| Agent | Role | Personality |
|-------|------|-------------|
| iori | Town Architect | Methodical, builds infrastructure |
| tsumugi | Creative Director | Energetic, creates gardens and art |
| saku | Safety Inspector | Cautious, patrols and documents |

## Project Structure

```
minetest-openclaw/
├── docker-compose.yml        # Podman-compatible compose
├── config/
│   └── minetest.conf         # Server configuration
├── minetest/mods/
│   └── openclaw_bot/         # Minetest Lua mod
│       ├── mod.conf
│       └── init.lua
├── bridge/                   # HTTP bridge server
│   ├── Dockerfile
│   ├── package.json
│   └── index.js
├── agents/
│   ├── templates/            # Shared workspace templates
│   └── instances/            # Per-agent identity files
│       ├── iori/
│       ├── tsumugi/
│       └── saku/
├── openclaw-skill/
│   └── mineworld/            # OpenClaw skill definition
│       └── SKILL.md
├── scripts/
│   ├── init.sh
│   ├── launch.sh
│   ├── stop.sh
│   └── test-bridge.sh
└── .env.example
```

## References

- [ONI-CADIA](https://github.com/Sunwood-ai-labs/ONI-CADIA) - AGI-country simulation with OpenClaw + Podman
- [OpenClaw](https://github.com/openclaw/openclaw) - Personal AI assistant
- [Minetest](https://www.minetest.net) - Free, open-source voxel game engine
- [Minetest Mod API](https://dev.minetest.net/Modding_Tutorial) - Lua modding documentation
