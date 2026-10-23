#!/usr/bin/env bash
# Herramientas de desarrollo en el HOME del usuario (sin root). Cada una puede fallar sin
# abortar las demás. Se ejecuta como el usuario en el primer arranque o en la instalación.
set -uo pipefail

export PATH="$HOME/.local/bin:$PATH"
mkdir -p "$HOME/.local/bin"

# Claude CLI (instalador oficial)
if ! command -v claude >/dev/null; then
  curl -fsSL https://claude.ai/install.sh | bash || echo "AVISO: Claude CLI no instalado." >&2
fi

# Codex CLI (npm con prefijo de usuario, sin sudo)
if command -v npm >/dev/null && ! command -v codex >/dev/null; then
  npm config set prefix "$HOME/.local"
  npm install -g @openai/codex || echo "AVISO: Codex CLI no instalado." >&2
fi

# herdr
bash "$(dirname "${BASH_SOURCE[0]}")/herdr.sh" || true
