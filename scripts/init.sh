#!/bin/bash
# init.sh - Initialize the OpenClaw World project
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "=== OpenClaw World - Initialize ==="
echo ""

# Check Podman
if ! command -v podman &> /dev/null; then
    echo "[ERROR] podman not found. Install with: brew install podman"
    echo "  Then run: podman machine init && podman machine start"
    exit 1
fi

# Check podman machine is running
if ! podman info &> /dev/null; then
    echo "[ERROR] Podman machine not running. Run: podman machine start"
    exit 1
fi
echo "[OK] Podman is running"

# Check podman-compose
if ! command -v podman-compose &> /dev/null; then
    echo "[WARN] podman-compose not found. Install with: pip3 install podman-compose"
    echo "  Alternatively, use docker-compose (Podman-compatible)"
fi

# Copy .env if needed
if [ ! -f .env ]; then
    cp .env.example .env
    echo "[OK] Created .env from .env.example"
else
    echo "[OK] .env already exists"
fi

# Install bridge dependencies
echo "[..] Installing bridge dependencies..."
cd bridge
npm install
cd "$PROJECT_ROOT"
echo "[OK] Bridge dependencies installed"

# Build bridge image
echo "[..] Building bridge container image..."
podman build -t minetest-bridge ./bridge
echo "[OK] Bridge image built"

echo ""
echo "=== Initialization complete ==="
echo ""
echo "Next steps:"
echo "  1. Edit .env with your LLM provider settings"
echo "  2. Run: ./scripts/launch.sh"
echo "  3. Connect Minetest client to localhost:30000"
