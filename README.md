# OpenClaw setup (CachyOS)

Local notes for the OpenClaw installation on this machine. Secrets live outside this repo.

## Status

| Component | Value |
|-----------|--------|
| OpenClaw | `2026.5.12` (`npm install -g openclaw@latest`) |
| Gateway | `http://127.0.0.1:18789/` (loopback only) |
| Model | `ollama/qwen2.5:3b` @ `http://127.0.0.1:11434` |
| Workspace | `~/Proyectos/Repos/jebstudios_ai_assistant` |
| Service | `systemctl --user` → `openclaw-gateway.service` |
| Linger | `loginctl enable-linger jebcalix` (24/7 user services) |

## Telegram stuck on "typing"

If the bot never replies, check:

1. **Ollama speed** — on CPU-only, `qwen2.5:3b` can take minutes per reply. Test: `curl -s http://127.0.0.1:11434/api/chat -d '{"model":"qwen2.5:3b","messages":[{"role":"user","content":"hi"}],"stream":false,"options":{"num_predict":10}}'`
2. **Stuck session** — `openclaw sessions cleanup && openclaw gateway restart`
3. **Lighter config** (already applied on this machine): `sandbox.mode: off`, `thinkingDefault: off`
4. **Better model** — use a cloud API in `openclaw configure`, or a smaller/faster local model, or enable GPU (ROCm/Vulkan) for Ollama on AMD.

## Quick commands

```bash
openclaw dashboard          # Control UI
openclaw gateway status     # Health
openclaw doctor             # Diagnostics
openclaw logs --follow      # Live logs
openclaw skills list        # Skills
openclaw cron list          # Scheduled jobs
```

## Enable Telegram

1. Create a bot with [@BotFather](https://t.me/BotFather) (`/newbot`) and copy the token.
2. Store the token (not in git):

```bash
cp ~/.config/openclaw/env.example ~/.config/openclaw/env
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
| `~/.config/systemd/user/openclaw-gateway.service.d/env.conf` | EnvironmentFile for gateway |

## Installed ClawHub skills (workspace)

- `github` — GitHub via `gh` CLI
- `git` — Git workflows

Bundled skills (e.g. `coding-agent`, `browser-automation`) are managed by OpenClaw; run `openclaw skills list`.

## Automation

- **Heartbeat:** `~/Proyectos/Repos/jebstudios_ai_assistant/HEARTBEAT.md` (30m interval)
- **Cron:** weekday 08:00 `America/Mexico_City` — “Weekday morning check-in”

## Security notes

- Gateway binds to **loopback** only.
- Small local model (`qwen2.5:3b`): sandbox `all`, web/browser tools denied for that model.
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
- https://docs.openclaw.ai/channels/telegram
