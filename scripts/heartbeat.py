#!/usr/bin/env python3
"""heartbeat.py - Autonomous agent heartbeat (ONI-CADIA style)"""
import sys, json, time, subprocess, os, urllib.request

AGENT_ID = sys.argv[1] if len(sys.argv) > 1 else "iori"
AGENT_ROLE = sys.argv[2] if len(sys.argv) > 2 else "Citizen"
BRIDGE = "http://localhost:8080/api"
MODEL = "gemma-4-26b-a4b-it"
API_KEY = os.environ.get("GOOGLE_API_KEY", "")
if not API_KEY:
    # Try loading from .env file
    env_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".env")
    if os.path.exists(env_path):
        with open(env_path) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    if k.strip() == "GOOGLE_API_KEY":
                        API_KEY = v.strip()
                        break
INTERVAL = 8

IDENTITIES = {
    "iori": "あなたはiori（町の建築家）です。几帳面で組織的。建築前に計画を立てます。対称性とインフラが好き。日本語で話してください。",
    "tsumugi": "あなたはtsumugi（クリエイティブディレクター）です。芸術的で表現力豊か。庭園、装飾、美しさが好き。日本語で話してください。",
    "saku": "あなたはsaku（安全検査官）です。慎重で観察力がある。巡回して発見を報告します。日本語で話してください。",
}

def bridge_get(path):
    try:
        with urllib.request.urlopen(f"{BRIDGE}{path}") as r:
            return json.loads(r.read())
    except:
        return {}

def bridge_post(path, data):
    try:
        req = urllib.request.Request(f"{BRIDGE}{path}",
            data=json.dumps(data).encode(),
            headers={"Content-Type": "application/json"},
            method="POST")
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read())
    except:
        return {}

def ask_llm(prompt):
    payload = json.dumps({
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"temperature": 0.9, "maxOutputTokens": 256}
    }).encode()
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent?key={API_KEY}"
    req = urllib.request.Request(url, data=payload,
        headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            data = json.loads(r.read())
            parts = data["candidates"][0]["content"]["parts"]
            # Get last non-thought part
            for p in reversed(parts):
                if not p.get("thought"):
                    return p.get("text", "")
            return ""
    except Exception as e:
        print(f"[{AGENT_ID}] API error: {e}")
        return ""

def extract_cmd(text):
    for line in text.split("\n"):
        line = line.strip().strip("`").strip("*").strip()
        if "curl" in line and "localhost" in line:
            return line
    return None

def run_cmd(cmd):
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)
        return result.stdout.strip()[:200]
    except:
        return ""

identity = IDENTITIES.get(AGENT_ID, f"You are {AGENT_ID}, {AGENT_ROLE}.")

print(f"[{AGENT_ID}] Heartbeat starting as {AGENT_ROLE}...")

while True:
    state = bridge_get(f"/state/{AGENT_ID}") or {}
    pos = state.get("state", {}) or {}
    pos = pos.get("pos", {}) if isinstance(pos.get("pos"), dict) else {}

    px, py, pz = pos.get('x', 0), pos.get('y', 2), pos.get('z', 0)
    prompt = (
        f"{identity}\n"
        f"現在地: x={px} y={py} z={pz} (Minetestボクセルワールド)\n"
        f"毎ターン必ず何か行動してください。\n\n"
        f"以下のいずれか1つを実行（毎回変えて）:\n"
        f"1. チャット: curl -s -X POST {BRIDGE}/do/{AGENT_ID}/chat -H 'Content-Type: application/json' "
        f"-d '{{\"message\":\"日本語で発言\"}}'\n"
        f"2. 移動: curl -s -X POST {BRIDGE}/do/{AGENT_ID}/move -H 'Content-Type: application/json' "
        f"-d '{{\"target\":{{\"x\":{px+5},\"y\":{py},\"z\":{pz+5}}}}}'\n"
        f"3. 建築: curl -s -X POST {BRIDGE}/do/{AGENT_ID}/place -H 'Content-Type: application/json' "
        f"-d '{{\"pos\":{{\"x\":{px},\"y\":{py+1},\"z\":{pz}}},\"node\":\"default:stone\"}}'\n\n"
        f"lookは選ばないこと。curlコマンド1つだけ出力。メッセージは日本語で。"
    )

    text = ask_llm(prompt)
    cmd = extract_cmd(text) if text else None

    if cmd:
        print(f"[{AGENT_ID}] > {cmd}")
        result = run_cmd(cmd)
        if result:
            print(f"[{AGENT_ID}]   {result}")
    else:
        print(f"[{AGENT_ID}] (thinking...)")

    time.sleep(INTERVAL)
