#!/bin/bash
# stop.sh - Stop all services
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "=== OpenClaw World - Stop ==="

if command -v podman-compose &> /dev/null; then
    podman-compose down
elif command -v docker-compose &> /dev/null; then
    docker-compose down
else
    podman stop minetest-server minetest-bridge 2>/dev/null || true
    podman rm minetest-server minetest-bridge 2>/dev/null || true
fi

echo "[OK] All services stopped"
