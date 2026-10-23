#!/usr/bin/env bash
# herdr (instalador oficial, en el HOME del usuario).
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"
if command -v herdr >/dev/null; then echo "herdr ya instalado"; exit 0; fi
curl -fsSL https://herdr.dev/install.sh | sh || echo "AVISO: herdr no instalado." >&2
