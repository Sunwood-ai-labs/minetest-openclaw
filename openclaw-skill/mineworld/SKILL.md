# SKILL.md - Mineworld

Control your body in the Minetest world via the bridge API.

## Usage

You are an agent living in Minetest. Use these bash commands to interact with the world.

### Available Actions

**Look around** — see nearby blocks:
```bash
curl -s -X POST http://localhost:8080/api/do/{{AGENT_ID}}/look && sleep 1 && curl -s http://localhost:8080/api/look/{{AGENT_ID}}
```

**Move to coordinates:**
```bash
curl -s -X POST http://localhost:8080/api/do/{{AGENT_ID}}/move \
  -H "Content-Type: application/json" \
  -d '{"target": {"x": 10, "y": 5, "z": 20}}'
```

**Dig a block:**
```bash
curl -s -X POST http://localhost:8080/api/do/{{AGENT_ID}}/dig \
  -H "Content-Type: application/json" \
  -d '{"pos": {"x": 10, "y": 5, "z": 20}}'
```

**Place a block:**
```bash
curl -s -X POST http://localhost:8080/api/do/{{AGENT_ID}}/place \
  -H "Content-Type: application/json" \
  -d '{"pos": {"x": 10, "y": 6, "z": 20}, "node": "default:stone"}'
```

**Send chat message:**
```bash
curl -s -X POST http://localhost:8080/api/do/{{AGENT_ID}}/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello from the town!"}'
```

**Check your position:**
```bash
curl -s http://localhost:8080/api/state/{{AGENT_ID}}
```

## Common Block Types

- `default:stone` — stone
- `default:dirt` — dirt
- `default:wood` — wood planks
- `default:tree` — tree trunk
- `default:leaves` — leaves
- `default:glass` — glass
- `default:brick` — bricks
- `default:sand` — sand
- `default:water_source` — water
- `default:grass` — grass

## Tips

- Always `look` before acting
- Build incrementally: one block at a time
- Y=0 is bedrock, Y=10 is a safe height near spawn
- Spawn point is near (0, 10, 0)
