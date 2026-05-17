#!/usr/bin/env bash
set -euo pipefail

# Enable Vulkan GPU for Ollama on Arch/Manjaro (AMD RX 580 and similar).
# The base `ollama` package ships CPU backends only; GPU needs `ollama-vulkan`.

if ! command -v pacman >/dev/null; then
  echo "This script is for Arch/Manjaro (pacman)."
  exit 1
fi

echo "=== Install Vulkan backend for Ollama ==="
sudo pacman -S --needed ollama vulkan-radeon lib32-vulkan-radeon ollama-vulkan

if ! ls /usr/lib/ollama/libggml-vulkan.so* >/dev/null 2>&1; then
  echo "ERROR: libggml-vulkan.so not found after install."
  exit 1
fi
echo "Vulkan backend: $(ls /usr/lib/ollama/libggml-vulkan.so*)"

echo
echo "=== GPU access (render + video groups) ==="
if groups | grep -qw render && groups | grep -qw video; then
  echo "User already in render and video groups."
else
  echo "Adding $USER to render and video (log out/in or reboot for group membership)..."
  sudo usermod -aG render,video "$USER"
fi

SERVICE_DIR="${HOME}/.config/systemd/user"
mkdir -p "${SERVICE_DIR}"
cp "$(dirname "$0")/../config/ollama.service.example" "${SERVICE_DIR}/ollama.service"

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
systemctl --user daemon-reload
systemctl --user restart ollama

echo
echo "=== Verify (expect library=vulkan, RX 580) ==="
sleep 3
journalctl --user -u ollama -n 20 --no-pager | grep -E "inference compute|vulkan|library=" || true

echo
echo "=== OpenClaw: use qwen2.5:7b (best fit for 8GB RX 580 on Vulkan) ==="
export PATH="${HOME}/.nvm/versions/node/v22.22.3/bin:${HOME}/.npm-global/bin:/usr/bin:${PATH}"
if command -v openclaw >/dev/null; then
  openclaw models set ollama/qwen2.5:7b
  openclaw config set agents.defaults.thinkingDefault '"off"' --strict-json 2>/dev/null || true
  openclaw gateway restart 2>/dev/null || true
  echo "OpenClaw default model: ollama/qwen2.5:7b"
else
  echo "openclaw not on PATH; run later:"
  echo "  openclaw models set ollama/qwen2.5:7b && openclaw gateway restart"
fi

echo
echo "Quick test:"
echo "  ollama run qwen2.5:7b \"Reply with exactly: ok\""
echo "  journalctl --user -u ollama -f   # expect Vulkan0 / library=Vulkan"
