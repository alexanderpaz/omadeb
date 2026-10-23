#!/usr/bin/env bash
# omadeb — instalación sobre un Debian 13 ya instalado (compila Hyprland).
# Para una instalación desde cero usa install.sh.
#
#   ~/.local/share/omadeb/post-install.sh            todo
#   ~/.local/share/omadeb/post-install.sh configs    solo la configuración
#
# Registro completo en ~/.cache/omadeb-install.log
set -euo pipefail

OMADEB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="$HOME/.cache/omadeb-install.log"
mkdir -p "$(dirname "$LOG")"

step() { printf '\n\e[1;35m━━ %s\e[0m\n' "$*"; }

if ! sudo -v; then
  echo "Necesito sudo. ¿Estás en el grupo sudo y volviste a iniciar sesión? (comprueba con: id)" >&2
  exit 1
fi
# Mantener vivo sudo mientras dure la compilación
while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &

{
  case "${1:-all}" in
    configs)
      step "Configuración"
      bash "$OMADEB/install/configs.sh" "${@:2}"
      ;;
    all)
      step "1/4 Paquetes de Debian"
      bash "$OMADEB/install/packages.sh"
      step "2/4 Fuentes"
      bash "$OMADEB/install/fonts.sh"
      step "3/4 Compilando Hyprland (30-60 min)"
      bash "$OMADEB/install/build-hypr.sh"
      step "4/4 Configuración"
      bash "$OMADEB/install/configs.sh"
      step "¡Listo!"
      echo "Cierra sesión y elige «Hyprland» en tu gestor de inicio de sesión."
      ;;
    *)
      echo "uso: post-install.sh [all|configs [--force]]" >&2
      exit 1
      ;;
  esac
} 2>&1 | tee -a "$LOG"
