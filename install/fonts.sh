#!/usr/bin/env bash
# JetBrainsMono Nerd Font (la fuente de Omarchy, con los iconos de la barra).
set -euo pipefail

FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerd"
VERSION=v3.4.0

if fc-list | grep -q "JetBrainsMono Nerd Font"; then
  echo "JetBrainsMono Nerd Font ya instalada"
  exit 0
fi

mkdir -p "$FONT_DIR"
curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/download/$VERSION/JetBrainsMono.tar.xz" |
  tar xJ -C "$FONT_DIR"
fc-cache -f "$FONT_DIR"
echo "JetBrainsMono Nerd Font instalada"
