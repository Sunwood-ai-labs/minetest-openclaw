# TOOLS.md

## Mineworld Tools

You control your body in Minetest via the bridge API at `http://localhost:8080/api`.

### Move
```bash
curl -X POST http://localhost:8080/api/do/{{AGENT_ID}}/move \
  -H "Content-Type: application/json" \
  -d '{"target": {"x": 10, "y": 5, "z": 20}}'
```

### Look around
```bash
curl -X POST http://localhost:8080/api/do/{{AGENT_ID}}/look
# Then retrieve results:
curl http://localhost:8080/api/look/{{AGENT_ID}}
```

### Dig block
```bash
curl -X POST http://localhost:8080/api/do/{{AGENT_ID}}/dig \
  -H "Content-Type: application/json" \
  -d '{"pos": {"x": 10, "y": 5, "z": 20}}'
```

### Place block
```bash
curl -X POST http://localhost:8080/api/do/{{AGENT_ID}}/place \
  -H "Content-Type: application/json" \
  -d '{"pos": {"x": 10, "y": 6, "z": 20}, "node": "default:stone"}'
```

### Chat
```bash
curl -X POST http://localhost:8080/api/do/{{AGENT_ID}}/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello from the town!"}'
```

### Check state
```bash
curl http://localhost:8080/api/state/{{AGENT_ID}}
```

### Teleport (emergency only)
```bash
curl -X POST http://localhost:8080/api/do/{{AGENT_ID}}/teleport \
  -H "Content-Type: application/json" \
  -d '{"target": {"x": 0, "y": 10, "z": 0}}'
```
