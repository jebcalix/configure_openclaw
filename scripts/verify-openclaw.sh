#!/usr/bin/env bash
set -euo pipefail

export PATH="${HOME}/.nvm/versions/node/v22.22.3/bin:${HOME}/.npm-global/bin:/usr/bin:${PATH}"

echo "=== Preflight ==="
if command -v node >/dev/null; then
  node_ver="$(node --version | tr -d v)"
  node_major="${node_ver%%.*}"
  node_minor_patch="${node_ver#*.}"
  node_minor="${node_minor_patch%%.*}"
  if [[ "${node_major}" -lt 22 ]] || [[ "${node_major}" -eq 22 && "${node_minor}" -lt 12 ]]; then
    echo "WARN: Node $(node --version) is below 22.12 (required by OpenClaw). Run: nvm install 22 && nvm alias default 22"
  else
    echo "Node: $(node --version)"
  fi
else
  echo "WARN: node not found on PATH"
fi

ollama_bin="$(command -v ollama || true)"
if [[ -z "${ollama_bin}" ]]; then
  echo "WARN: ollama not found on PATH"
elif [[ "${ollama_bin}" == /usr/local/bin/ollama ]]; then
  echo "WARN: /usr/local/bin/ollama shadows pacman Ollama. Run: sudo mv /usr/local/bin/ollama /usr/local/bin/ollama.bak"
else
  echo "Ollama: ${ollama_bin} ($(ollama --version 2>&1 | tail -1))"
fi

if curl -sf http://127.0.0.1:11434/api/tags >/dev/null; then
  echo "Ollama API: ok (127.0.0.1:11434)"
else
  echo "WARN: Ollama not reachable. Start: systemctl --user start ollama"
fi

if systemctl --user is-active --quiet ollama.service 2>/dev/null; then
  echo "Ollama service: active (user)"
elif systemctl is-active --quiet ollama.service 2>/dev/null; then
  echo "Ollama service: active (system)"
else
  echo "WARN: ollama.service not active"
fi

echo
echo "=== OpenClaw verify ==="
openclaw --version
echo
openclaw doctor 2>&1 | tail -20
echo
openclaw gateway status 2>&1 | head -22
echo
echo "=== Models (Ollama) ==="
openclaw models list --provider ollama 2>&1 | head -10 || true
echo
echo "=== Skills (ready) ==="
openclaw skills list 2>&1 | grep '✓ ready' | head -15 || true
echo
echo "=== Cron ==="
openclaw cron list 2>&1 || true
