#!/bin/bash
# heartbeat.sh - Autonomous agent heartbeat loop (ONI-CADIA style)
set -e

BRIDGE="http://localhost:8080/api"
AGENT_ID="${1:?Usage: heartbeat.sh <agent_id> [role]}"
AGENT_ROLE="${2:-Citizen}"
MODEL="gemma-4-26b-a4b-it"
API_KEY="${GOOGLE_API_KEY:?Set GOOGLE_API_KEY}"

echo "[${AGENT_ID}] Heartbeat starting as ${AGENT_ROLE}..."

while true; do
    STATE=$(curl -s "${BRIDGE}/state/${AGENT_ID}" 2>/dev/null || echo '{}')

    # Build prompt and JSON payload
    PROMPT="You are ${AGENT_ID} (${AGENT_ROLE}), living in a Minetest voxel world.
Your tools: curl commands to http://localhost:8080/api/do/${AGENT_ID}/ACTION
Actions: look, move {target:{x,y,z}}, chat {message}, dig {pos:{x,y,z}}, place {pos:{x,y,z},node}
Current state: ${STATE}
Decide ONE action. Output ONLY the curl command, no explanation."

    PAYLOAD=$(python3 << PYEOF
import json, sys
print(json.dumps({
    "contents": [{"parts": [{"text": sys.argv[1]}]}],
    "generationConfig": {"temperature": 0.9, "maxOutputTokens": 256}
}))
PYEOF
)

    # Build payload properly
    PAYLOAD=$(python3 -c "
import json, sys
print(json.dumps({
    'contents': [{'parts': [{'text': sys.stdin.read().strip()}]}],
    'generationConfig': {'temperature': 0.9, 'maxOutputTokens': 256}
}))
" <<< "$PROMPT")

    RESPONSE=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${API_KEY}" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD" 2>/dev/null)

    CMD=$(echo "$RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    parts = data['candidates'][0]['content']['parts']
    for p in reversed(parts):
        text = p.get('text', '')
        if p.get('thought'): continue
        for line in text.strip().split(chr(10)):
            line = line.strip().strip('\`').strip('*').strip()
            if 'curl' in line and 'localhost' in line:
                print(line)
                sys.exit(0)
    print('NO_CMD')
except:
    print('NO_CMD')
" 2>/dev/null)

    if [ "$CMD" != "NO_CMD" ] && [ -n "$CMD" ]; then
        echo "[${AGENT_ID}] > $CMD"
        eval "$CMD" 2>/dev/null || true
    else
        echo "[${AGENT_ID}] (thinking...)"
    fi

    sleep 5
done
