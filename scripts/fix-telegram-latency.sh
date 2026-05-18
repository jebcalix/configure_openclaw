#!/usr/bin/env bash
# Reset bloated OpenClaw sessions and apply Telegram-friendly latency settings.
set -euo pipefail

export PATH="${HOME}/.nvm/versions/node/v22.22.3/bin:${HOME}/.npm-global/bin:/usr/bin:${PATH}"

if ! command -v openclaw >/dev/null; then
  echo "openclaw not on PATH"
  exit 1
fi

CONFIG="${HOME}/.openclaw/openclaw.json"
SESSION_DIR="${HOME}/.openclaw/agents/main/sessions"
ARCHIVE_DIR="${SESSION_DIR}/archive-$(date +%Y%m%d-%H%M%S)"

echo "=== Apply latency-oriented OpenClaw settings ==="
openclaw config set tools.profile '"minimal"' --strict-json
openclaw config set agents.defaults.contextInjection '"never"' --strict-json
openclaw config set agents.defaults.bootstrapMaxChars 2000 --strict-json
openclaw config set agents.defaults.bootstrapTotalMaxChars 5000 --strict-json
openclaw config set agents.defaults.startupContext.enabled false --strict-json
openclaw config set skills.limits.maxSkillsPromptChars 800 --strict-json

echo "=== Archive large session transcripts ==="
mkdir -p "${ARCHIVE_DIR}"
find "${SESSION_DIR}" -maxdepth 1 \( -name '*.jsonl' -o -name '*.trajectory.jsonl' \) -size +100k -print -exec mv {} "${ARCHIVE_DIR}/" \;

if [[ -f "${HOME}/.openclaw/workspace/BOOTSTRAP.md" ]]; then
  mv "${HOME}/.openclaw/workspace/BOOTSTRAP.md" "${HOME}/.openclaw/workspace/BOOTSTRAP.md.done"
  echo "Renamed BOOTSTRAP.md -> BOOTSTRAP.md.done (onboarding file no longer injected)"
fi

TOKEN="$(python3 -c "import json; print(json.load(open('${CONFIG}'))['gateway']['auth']['token'])")"

echo "=== Reset sessions ==="
openclaw gateway call sessions.reset --token "${TOKEN}" --params '{"key":"agent:main:main"}' --json >/dev/null || true
openclaw gateway call sessions.delete --token "${TOKEN}" --params '{"key":"agent:main:telegram:direct:32797171"}' --json >/dev/null || true

echo "=== Restart gateway ==="
openclaw gateway restart

echo
echo "Done. In Telegram send: /reset"
echo "Then test with a short message. Expect ~20-45s per reply on qwen2.5:7b (not instant like bare ollama run)."
echo "Archived transcripts: ${ARCHIVE_DIR}"
