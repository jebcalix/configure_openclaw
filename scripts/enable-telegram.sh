#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${HOME}/.config/openclaw/env"
export PATH="${HOME}/.npm-global/bin:${PATH}"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}"
  echo "Copy env.example: cp ~/.config/openclaw/env.example ~/.config/openclaw/env"
  exit 1
fi

# shellcheck disable=SC1090
set -a
source "${ENV_FILE}"
set +a

if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]]; then
  echo "TELEGRAM_BOT_TOKEN is empty in ${ENV_FILE}"
  exit 1
fi

openclaw config set channels.telegram.enabled true --strict-json
systemctl --user daemon-reload
openclaw gateway restart

echo "Telegram enabled. Message your bot, then run:"
echo "  openclaw pairing list telegram"
echo "  openclaw pairing approve telegram <CODE>"
