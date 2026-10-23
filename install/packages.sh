#!/usr/bin/env bash
# Instala paquetes de Debian 13 en el sistema actual (usado por post-install.sh).
#   packages.sh            dependencias de compilación + escritorio (compilar Hyprland aquí)
#   packages.sh desktop    solo el escritorio, sin toolchain (Hyprland viene de los .deb)
set -euo pipefail

# shellcheck source=packages.list.sh
source "$(dirname "${BASH_SOURCE[0]}")/packages.list.sh"

sudo apt-get update
if [[ ${1:-} != desktop ]]; then
  sudo apt-get install -y --no-install-recommends "${BUILD_DEPS[@]}"
fi
sudo apt-get install -y --no-install-recommends "${SYSTEM[@]}" "${DESKTOP[@]}" "${FILES[@]}"
