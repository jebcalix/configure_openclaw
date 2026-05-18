#!/usr/bin/env bash
# Install OpenCode (latest) and apply Ollama-optimized config for this machine.
set -euo pipefail

export PATH="${HOME}/.nvm/versions/node/v22.22.3/bin:${HOME}/npm-global/bin:/usr/bin:${PATH}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_SRC="${REPO_ROOT}/config/opencode.json.example"
CONFIG_DST="${HOME}/.config/opencode/opencode.json"
ENV_SNIPPET="${HOME}/.config/opencode/env.sh"

echo "=== OpenCode install (latest) ==="
if command -v opencode >/dev/null && opencode --version >/dev/null 2>&1; then
  echo "Already installed: $(opencode --version)"
  echo "Upgrading..."
  opencode upgrade --method curl 2>/dev/null || curl -fsSL https://opencode.ai/install | bash
else
  curl -fsSL https://opencode.ai/install | bash
fi

export PATH="${HOME}/.opencode/bin:${PATH}"
echo "Version: $(opencode --version)"

echo
echo "=== Ollama service ==="
if ! systemctl --user is-active ollama >/dev/null 2>&1; then
  echo "Starting user ollama.service..."
  systemctl --user start ollama || true
fi
if ! curl -sf http://127.0.0.1:11434/api/tags >/dev/null; then
  echo "ERROR: Ollama not reachable at http://127.0.0.1:11434"
  exit 1
fi
if ! ollama list 2>/dev/null | grep -q 'qwen2.5:7b'; then
  echo "Pulling qwen2.5:7b..."
  ollama pull qwen2.5:7b
fi

echo
echo "=== Config ==="
mkdir -p "${HOME}/.config/opencode"
cp "${CONFIG_SRC}" "${CONFIG_DST}"
chmod 600 "${CONFIG_DST}"

cat >"${ENV_SNIPPET}" <<'EOF'
# OpenCode + Ollama (local RX 580 / qwen2.5:7b)
export PATH="${HOME}/.opencode/bin:${PATH}"
export OLLAMA_HOST="http://127.0.0.1:11434"
# Faster startup when you only use local Ollama (optional)
export OPENCODE_DISABLE_MODELS_FETCH="${OPENCODE_DISABLE_MODELS_FETCH:-true}"
# Longer tool timeouts for slow local inference
export OPENCODE_EXPERIMENTAL_BASH_DEFAULT_TIMEOUT_MS="${OPENCODE_EXPERIMENTAL_BASH_DEFAULT_TIMEOUT_MS:-300000}"
EOF
chmod 600 "${ENV_SNIPPET}"

if ! grep -q 'opencode/env.sh' "${HOME}/.zshrc" 2>/dev/null; then
  cat >>"${HOME}/.zshrc" <<EOF

# OpenCode (Ollama local)
[ -f "\${HOME}/.config/opencode/env.sh" ] && source "\${HOME}/.config/opencode/env.sh"
EOF
  echo "Appended env snippet to ~/.zshrc"
fi

echo
echo "=== Verify ==="
source "${ENV_SNIPPET}"
opencode models ollama

echo
echo "Done."
echo "  Config: ${CONFIG_DST}"
echo "  Docs:   ${REPO_ROOT}/docs/OPENCODE.md"
echo "  Run:    cd your-project && opencode"
echo "  Or:     ollama launch opencode --model qwen2.5:7b"
