#!/usr/bin/env bash
set -euo pipefail

export PATH="${HOME}/.npm-global/bin:${PATH}"

echo "=== OpenClaw verify ==="
openclaw --version
echo
openclaw doctor 2>&1 | tail -20
echo
openclaw gateway status 2>&1 | head -22
echo
echo "=== Skills (ready) ==="
openclaw skills list 2>&1 | grep '✓ ready' | head -15 || true
echo
echo "=== Cron ==="
openclaw cron list 2>&1 || true
