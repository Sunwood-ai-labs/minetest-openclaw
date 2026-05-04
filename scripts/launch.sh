#!/bin/bash
# launch.sh - Start Minetest server + Bridge
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "=== OpenClaw World - Launch ==="
echo ""

# Check if already running
if podman ps --format "{{.Names}}" | grep -q "minetest-server"; then
    echo "[WARN] Minetest server is already running"
    echo "  Stop first with: ./scripts/stop.sh"
    exit 1
fi

echo "[..] Starting Minetest server + Bridge..."

# Use podman-compose or docker-compose
if command -v podman-compose &> /dev/null; then
    podman-compose up -d
elif command -v docker-compose &> /dev/null; then
    docker-compose up -d
else
    echo "[ERROR] Neither podman-compose nor docker-compose found"
    exit 1
fi

echo ""
echo "[OK] Services started"
echo ""
echo "  Minetest server: localhost:30000"
echo "  Bridge API:      http://localhost:8080"
echo ""
echo "Connect with Minetest client:"
echo "  Address: localhost:30000"
echo ""
echo "Test the bridge:"
echo "  curl http://localhost:8080/api/health"
echo ""
echo "Watch logs:"
echo "  podman logs -f minetest-server"
echo "  podman logs -f minetest-bridge"
