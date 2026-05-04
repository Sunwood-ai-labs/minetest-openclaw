# 引き継ぎ資料 — minetest-openclaw

最終更新: 2026-05-04

## プロジェクト概要

OpenClawエージェントがMinetestの世界で「生活」するシステム。
[ONI-CADIA](https://github.com/Sunwood-ai-labs/ONI-CADIA)の「1市民=1Pod」アーキテクチャを踏襲し、Mattermostのチャットではなく**Minetestの物理世界**を居住空間としている。

Minetest（無料・オープンソース）を使うため、Minecraftの購入不要。完全合法。

## 現在の状態

**実装済み、未起動・未テスト。**

- 全ファイル作成済み（21ファイル）
- Podman上での動作を想定しているが、まだ `./scripts/init.sh` を実行していない
- Minetestサーバー・Bridgeともに起動確認なし
- OpenClawエージェントとの連携は設計のみ（動作検証なし）

## アーキテクチャ

```
Podman
├── Minetest Server (:30000)
│   └── openclaw_bot mod (Lua)
│       ├── NPC entity を生成・操作
│       ├── 0.5秒ごとに Bridge を HTTP ポーリング
│       └── コマンド実行: move, dig, place, chat, look
│
├── Bridge Server (:8080, Node.js/Express)
│   ├── OpenClaw → REST API → コマンドキュー
│   ├── Minetest mod がキューをポーリング → コマンド取得
│   ├── mod が state/look 結果を POST → Bridge が保持
│   └── OpenClaw が state/look を GET → 結果取得
│
└── OpenClaw Agent (Podman Pod, 個別起動)
    ├── iori  — Town Architect（インフラ・建築）
    ├── tsumugi — Creative Director（庭園・装飾）
    └── saku — Safety Inspector（巡回・記録）
```

通信フロー:
1. OpenClaw agent が `curl` で Bridge にコマンドを投げる
2. Bridge がコマンドキューに積む
3. Minetest mod が 0.5秒ごとに Bridge の `/api/sync` をポーリング
4. mod がコマンドを実行（NPC移動・ブロック破壊等）
5. mod が state を Bridge に POST
6. OpenClaw agent が state を GET で確認

## ファイル一覧と役割

```
minetest-openclaw/
│
├── docker-compose.yml        # Podman/Docker Compose定義
│                             # Minetest + Bridge の2サービス
│
├── config/
│   └── minetest.conf         # Minetestサーバー設定
│                             # secure.trusted_mods=openclaw_bot が必須
│
├── minetest/mods/openclaw_bot/
│   ├── mod.conf              # Mod定義
│   └── init.lua              # Mod本体（約200行のLua）
│       ├── NPC entity の登録
│       ├── ブリッジポーリングループ
│       ├── コマンド実行（move/dig/place/chat/look）
│       └── state 定期報告
│
├── bridge/
│   ├── Dockerfile            # bridge コンテナ定義
│   ├── package.json          # 依存: express のみ
│   └── index.js              # Bridge サーバー（約150行）
│       ├── GET  /api/sync       → mod用: エージェント一覧 + コマンド取得
│       ├── POST /api/state/:id  → mod用: state 報告受付
│       ├── POST /api/look/:id   → mod用: look 結果受付
│       ├── POST /api/agents     → エージェント登録
│       ├── GET  /api/agents     → エージェント一覧+state
│       ├── GET  /api/state/:id  → state 取得
│       ├── POST /api/command/:id → コマンド投入
│       ├── POST /api/do/:id/:action → コマンド投入ショートカット
│       ├── GET  /api/look/:id   → look 結果取得
│       └── GET  /api/health     → ヘルスチェック
│
├── agents/
│   ├── templates/            # 全エージェント共通テンプレート
│   │   ├── SOUL.md           # 市民としての価値観・行動原則
│   │   ├── IDENTITY.md       # 個別IDのテンプレート（変数付き）
│   │   ├── HEARTBEAT.md      # ハートビート時の行動サイクル
│   │   └── TOOLS.md          # Bridge API の使い方（curl例）
│   └── instances/            # 個別エージェント定義
│       ├── iori/IDENTITY.md  # 建築家・インフラ担当
│       ├── tsumugi/IDENTITY.md # クリエイター・装飾担当
│       └── saku/IDENTITY.md  # 巡回員・安全確認担当
│
├── openclaw-skill/mineworld/
│   └── SKILL.md              # OpenClaw skill 定義
│                             # {{AGENT_ID}} を実際のIDに置換して使用
│
├── scripts/
│   ├── init.sh               # 初期化（podman確認, npm install, イメージビルド）
│   ├── launch.sh             # サービス起動
│   ├── stop.sh               # サービス停止
│   └── test-bridge.sh        # Bridge API の動作テスト
│
├── .env.example              # 環境変数テンプレート
├── README.md                 # セットアップガイド
└── HANDOVER.md               # 本ファイル
```

## 起動手順（まだ実行していない）

```bash
# 前提: macOS + Podman + Minetest client

# 1. Podman 準備
brew install podman
podman machine init
podman machine start

# 2. Minetest クライアント
brew install --cask minetest

# 3. プロジェクト初期化
cd ~/Prj/minetest-openclaw
./scripts/init.sh

# 4. 起動
./scripts/launch.sh

# 5. Minetest クライアントで接続
#    Address: localhost  Port: 30000

# 6. Bridge 動作確認
./scripts/test-bridge.sh

# 7. OpenClaw エージェント起動（別途）
npm install -g openclaw@latest
openclaw onboard
```

## 未解決・懸念事項

### 確認が必要なこと

1. **Minetest Dockerイメージの互換性**
   - `ghcr.io/minetest/minetest:latest` が Podman で正常動作するか未確認
   - ボリュームマウントパスが公式イメージと合うか要確認
   - `secure.trusted_mods` が反映されるパスに mod が配置されるか要確認

2. **Mod → Bridge の HTTP 通信**
   - Minetest mod の `request_http_api()` がコンテナ間通信（`http://bridge:8080`）を許可するか
   - `secure.trusted_mods` に加えて `secure.http_mods` の設定が必要かもしれない

3. **NPC entity の mesh/texture**
   - `character.b3d` と `character.png` がデフォルトでMinetestに同梱されているか
   - 同梱されていない場合、テクスチャの用意が必要

4. **macOS + Podman のネットワーク**
   - `podman machine` はVM上で動くため、ポートフォワーディングの挙動に注意
   - Minetest (UDP 30000) のフォワーディングが正しく働くか

5. **OpenClaw エージェントの実際の連携**
   - OpenClaw skill の `{{AGENT_ID}}` 置換をどう自動化するか
   - ハートビート（定期実行）で agent が自律的に Bridge API を叩く設定が未着手
   - OpenClaw の Podman Pod 定義（pod.yaml）が未作成

### 今後の拡張アイデア

- **Mattermost 連携**: ONI-CADIA本家のようにエージェント間チャットを追加
- **インベントリシステム**: エージェントがブロックを収集・管理
- **建築テンプレート**: エージェントに家・道・橋などの設計図を与える
- **観察者モード**: 人間はプレイせず、エージェントの行動を観察するだけのモード
- **Web UI**: Bridge の state をブラウザで可視化

## 参考

- ONI-CADIA: https://github.com/Sunwood-ai-labs/ONI-CADIA
- OpenClaw: https://github.com/openclaw/openclaw
- Minetest: https://www.minetest.net
- Minetest Mod API: https://dev.minetest.net/Modding_Tutorial
- Minetest Docker: https://github.com/minetest/minetest/pkgs/container/minetest
