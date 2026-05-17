# OpenClaw setup (Manjaro / Arch)

Local notes and install guide for OpenClaw with **Ollama (local only)** on this machine. Secrets live outside this repo.

## Status

| Component | Value |
|-----------|--------|
| OpenClaw | `2026.5.12` (`npm install -g openclaw@latest`) |
| Node | `22.22.3` via nvm (required: `22.12+`) |
| Gateway | `http://127.0.0.1:18789/` (loopback only) |
| Model | `ollama/qwen2.5:7b` @ `http://127.0.0.1:11434` |
| Ollama | `0.22.1` (pacman `/usr/bin/ollama`) |
| Ollama service | `systemctl --user` → `ollama.service` |
| OpenClaw service | `systemctl --user` → `openclaw-gateway.service` |
| GPU | AMD RX 580 8GB — Vulkan enabled; CPU inference if GPU not detected |

## Prerequisites

- **OS:** Manjaro, Arch, or CachyOS (pacman)
- **Node.js:** 22.16+ (24 recommended). Install via [nvm](https://github.com/nvm-sh/nvm) or [nodejs.org](https://nodejs.org/)
- **Ollama:** `sudo pacman -S ollama`
- **Vulkan (AMD):** `sudo pacman -S --needed vulkan-radeon lib32-vulkan-radeon`
- **Optional:** Docker (only if `sandbox.mode` is `all`)

Hardware profile for this repo (reference):

| Resource | This machine |
|----------|----------------|
| CPU | AMD Ryzen 5 4600G (6c / 12t) |
| RAM | 30 GiB |
| GPU | Radeon RX 580 8GB |

## Install from scratch

### 1. Node.js 22+

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
source ~/.zshrc   # or ~/.bashrc
nvm install 22
nvm alias default 22
nvm use 22
node --version    # must be >= v22.12.0
```

Add Node to your shell `PATH` if needed:

```bash
export PATH="$HOME/.nvm/versions/node/$(node -v | tr -d v | cut -d. -f1-2).x/bin:$PATH"
```

### 2. Ollama (fix PATH, install package)

**Critical:** An old Ollama binary at `/usr/local/bin/ollama` (v0.6.x) can shadow the pacman package and break the CLI. Remove it:

```bash
sudo mv /usr/local/bin/ollama /usr/local/bin/ollama.bak   # if present
which ollama          # must be /usr/bin/ollama
ollama --version      # must be 0.22.x
```

Install if missing:

```bash
sudo pacman -S ollama
```

#### User service (recommended, no root for daily use)

Copy the example unit and enable it:

```bash
mkdir -p ~/.config/systemd/user
cp config/ollama.service.example ~/.config/systemd/user/ollama.service
systemctl --user daemon-reload
systemctl --user enable --now ollama
systemctl --user status ollama
curl -s http://127.0.0.1:11434/api/tags
```

The example sets `OLLAMA_VULKAN=1` for AMD GPUs (RX 580). If Ollama logs show only `library=cpu`, inference still works on CPU/RAM.

#### System service (alternative)

```bash
sudo systemctl enable --now ollama
```

Optional GPU drop-in for the **system** unit:

```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/vulkan.conf <<'EOF'
[Service]
Environment=OLLAMA_VULKAN=1
EOF
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

### 3. Pull the local model

| Model | When to use |
|-------|-------------|
| **`qwen2.5:7b`** (default) | Best balance on **RX 580 8GB + Vulkan** (~8s replies); OpenClaw default after GPU setup |
| **`qwen2.5:3b`** (fallback) | If 7b OOMs or you need the fastest replies; lower quality |

```bash
ollama pull qwen2.5:7b
```

Smoke test:

```bash
curl -s http://127.0.0.1:11434/api/chat -d '{
  "model":"qwen2.5:7b",
  "messages":[{"role":"user","content":"Reply with exactly: ok"}],
  "stream":false,
  "options":{"num_predict":10}
}'
```

CPU fallback:

```bash
ollama pull qwen2.5:3b
openclaw models set ollama/qwen2.5:3b
openclaw gateway restart
```

### 4. Install OpenClaw

```bash
npm install -g openclaw@latest
openclaw --version
```

### 5. Onboard (Ollama, local only)

Interactive:

```bash
export OLLAMA_API_KEY=ollama-local
openclaw onboard --install-daemon
# Provider: Ollama → Local only → http://127.0.0.1:11434 → qwen2.5:7b
```

Non-interactive:

```bash
export OLLAMA_API_KEY=ollama-local
openclaw onboard --non-interactive \
  --auth-choice ollama \
  --custom-base-url "http://127.0.0.1:11434" \
  --custom-model-id "qwen2.5:7b" \
  --accept-risk \
  --install-daemon
```

Use the native Ollama URL (`http://127.0.0.1:11434`) — **not** `/v1` (breaks tool calling).

### 6. Optional config hardening

Merge patterns from [`config/openclaw.json.example`](config/openclaw.json.example):

```bash
openclaw config set agents.defaults.sandbox.mode '"off"' --strict-json
openclaw config set tools.byProvider '{"ollama/qwen2.5:7b":{"deny":["group:web","browser"]}}' --strict-json
openclaw gateway restart
```

### 7. Run 24/7 (user services)

```bash
loginctl enable-linger "$USER"   # may need: sudo loginctl enable-linger "$USER"
systemctl --user enable --now ollama.service
systemctl --user enable --now openclaw-gateway.service
```

Verify:

```bash
./scripts/verify-openclaw.sh
openclaw dashboard
```

## GPU on AMD RX 580

- **ROCm:** Modern ROCm drops Polaris (gfx803). Not required for this guide.
- **Vulkan (recommended):** On Arch/Manjaro the base `ollama` package is **CPU-only**. Install the Vulkan backend and enable the service:

```bash
./scripts/enable-ollama-gpu.sh
# or manually:
sudo pacman -S --needed ollama-vulkan vulkan-radeon lib32-vulkan-radeon
sudo usermod -aG render,video "$USER"   # then log out/in
cp config/ollama.service.example ~/.config/systemd/user/ollama.service
systemctl --user daemon-reload && systemctl --user restart ollama
```

  `GGML_VK_VISIBLE_DEVICES=0` selects the discrete RX 580 (GPU 1 is integrated Renoir).

- **Verify:** `journalctl --user -u ollama -n 30 | grep inference` should show `library=vulkan` and `AMD Radeon RX 580`, not `library=cpu`. Then `ollama run qwen2.5:7b "hi"` should be much faster than CPU-only.

## Telegram stuck on "typing"

If the bot never replies, check:

1. **Ollama speed** — on CPU, `qwen2.5:7b` can take minutes per reply. Test:

```bash
curl -s http://127.0.0.1:11434/api/chat -d '{"model":"qwen2.5:7b","messages":[{"role":"user","content":"hi"}],"stream":false,"options":{"num_predict":10}}'
```

2. **Stuck session** — `openclaw sessions cleanup && openclaw gateway restart`
3. **Lighter config:** `sandbox.mode: off`, disable thinking in agent settings
4. **Faster model** — `ollama pull qwen2.5:3b` and `openclaw models set ollama/qwen2.5:3b`

## Fix common issues

| Symptom | Fix |
|---------|-----|
| `openclaw: Node.js v22.12+ is required` | `nvm use 22` / `nvm alias default 22` |
| `Gateway restart blocked` (binary 2026.4.x vs config 2026.5.x) | `nvm use 22.22.3` then `openclaw --version` must show **2026.5.12**; remove old copy: `nvm use 22.22.2 && npm uninstall -g openclaw` |
| `could not connect to ollama` | `systemctl --user start ollama` |
| Wrong Ollama version (0.6.x) | `sudo mv /usr/local/bin/ollama /usr/local/bin/ollama.bak` |
| Gateway `ECONNREFUSED :18789` | `openclaw gateway restart` or `openclaw onboard --install-daemon` |
| Services stop after logout | `sudo loginctl enable-linger "$USER"` |

## Quick commands

```bash
openclaw dashboard          # Control UI
openclaw gateway status     # Health
openclaw doctor             # Diagnostics
openclaw logs --follow      # Live logs
openclaw skills list        # Skills
openclaw cron list          # Scheduled jobs
openclaw models list --provider ollama
```

## Enable Telegram

1. Create a bot with [@BotFather](https://t.me/BotFather) (`/newbot`) and copy the token.
2. Store the token (not in git):

```bash
mkdir -p ~/.config/openclaw
cp config/env.example ~/.config/openclaw/env
chmod 600 ~/.config/openclaw/env
# Edit env and set: TELEGRAM_BOT_TOKEN=123456:ABC...
```

3. Run the helper script:

```bash
./scripts/enable-telegram.sh
```

4. Message your bot on Telegram, then approve pairing:

```bash
openclaw pairing list telegram
openclaw pairing approve telegram <CODE>
```

5. Optional: lock DMs to your user ID only:

```bash
openclaw config set channels.telegram.dmPolicy '"allowlist"'
openclaw config set commands.ownerAllowFrom '["telegram:YOUR_NUMERIC_ID"]'
openclaw gateway restart
```

## Config files

| Path | Purpose |
|------|---------|
| `~/.openclaw/openclaw.json` | Main config |
| `~/.config/openclaw/env` | `TELEGRAM_BOT_TOKEN` (systemd loads via drop-in) |
| `~/.config/systemd/user/ollama.service` | User Ollama daemon |
| `~/.config/systemd/user/openclaw-gateway.service` | OpenClaw gateway |
| `config/openclaw.json.example` | Reference config for this repo |
| `config/ollama.service.example` | User Ollama unit template |

## Installed ClawHub skills (workspace)

- `github` — GitHub via `gh` CLI
- `git` — Git workflows

Bundled skills (e.g. `coding-agent`, `browser-automation`) are managed by OpenClaw; run `openclaw skills list`.

## Automation

- **Heartbeat:** configure in your agent workspace `HEARTBEAT.md`
- **Cron:** `openclaw cron list`

## Security notes

- Gateway binds to **loopback** only.
- Local models: deny web/browser tools per provider in `tools.byProvider`.
- Docker sandbox image required when `sandbox.mode` is `all`:

```bash
docker build -t openclaw-sandbox:bookworm-slim - <<'DOCKERFILE'
FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
  bash ca-certificates curl git jq python3 ripgrep \
  && rm -rf /var/lib/apt/lists/*
RUN useradd --create-home --shell /bin/bash sandbox
USER sandbox
WORKDIR /home/sandbox
CMD ["sleep", "infinity"]
DOCKERFILE
```

- Do not commit tokens or `~/.openclaw/openclaw.json` (contains gateway token).

## Docs

- https://docs.openclaw.ai
- https://docs.openclaw.ai/providers/ollama
- https://docs.openclaw.ai/channels/telegram
