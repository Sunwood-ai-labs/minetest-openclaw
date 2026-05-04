#!/bin/bash
# test-bridge.sh - Test the bridge API without Minetest
set -e

BRIDGE="http://localhost:8080/api"

echo "=== Bridge API Test ==="
echo ""

echo "[1] Health check..."
curl -s "$BRIDGE/health" | python3 -m json.tool
echo ""

echo "[2] Register test agent..."
curl -s -X POST "$BRIDGE/agents" \
  -H "Content-Type: application/json" \
  -d '{"agent_id": "test-bot"}' | python3 -m json.tool
echo ""

echo "[3] List agents..."
curl -s "$BRIDGE/agents" | python3 -m json.tool
echo ""

echo "[4] Send move command..."
curl -s -X POST "$BRIDGE/command/test-bot" \
  -H "Content-Type: application/json" \
  -d '{"action": "move", "target": {"x": 5, "y": 10, "z": 5}}' | python3 -m json.tool
echo ""

echo "[5] Send chat command..."
curl -s -X POST "$BRIDGE/command/test-bot" \
  -H "Content-Type: application/json" \
  -d '{"action": "chat", "message": "Hello World!"}' | python3 -m json.tool
echo ""

echo "[6] Send look command..."
curl -s -X POST "$BRIDGE/do/test-bot/look" | python3 -m json.tool
echo ""

echo "[7] Check pending sync (what mod would see)..."
curl -s "$BRIDGE/sync" | python3 -m json.tool
echo ""

echo "=== All tests passed ==="
