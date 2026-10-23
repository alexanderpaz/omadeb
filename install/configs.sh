#!/usr/bin/env bash
# Instala la configuración de omadeb en ~/.config.
# La primera vez respalda lo que ya hubiera; en ejecuciones siguientes no pisa
# tus cambios (usa --force para restaurar los valores de omadeb).
set -euo pipefail

OMADEB="$HOME/.local/share/omadeb"
CONFIG="$HOME/.config"
MARKER="$CONFIG/omadeb/.installed"
MANAGED=(hypr waybar alacritty swayosd btop fastfetch mako fuzzel xdg-desktop-portal)

force=false
[[ ${1:-} == --force ]] && force=true

if [[ ! -f $MARKER ]]; then
  backup="$CONFIG/omadeb-backup-$(date +%Y%m%d-%H%M%S)"
  for dir in "${MANAGED[@]}"; do
    if [[ -e $CONFIG/$dir ]]; then
      mkdir -p "$backup"
      mv "$CONFIG/$dir" "$backup/"
    fi
  done
  [[ -d ${backup:-} ]] && echo "Configuración anterior respaldada en $backup"
  force=true
fi

if $force; then
  cp -r "$OMADEB/config/." "$CONFIG/"
else
  cp -rn "$OMADEB/config/." "$CONFIG/"
fi

# Scripts en el PATH (~/.local/bin lo añade el ~/.profile de Debian)
mkdir -p "$HOME/.local/bin"
for script in "$OMADEB"/bin/*; do
  chmod +x "$script"
  ln -sfn "$script" "$HOME/.local/bin/$(basename "$script")"
done
export PATH="$HOME/.local/bin:$PATH"

# Tema inicial, y enlaces de las apps que no admiten "include"
mkdir -p "$CONFIG/omadeb"
if [[ ! -f $CONFIG/omadeb/current/theme.name ]]; then
  # Sin sesión (chroot del instalador) gsettings necesita un bus propio.
  if command -v dbus-run-session >/dev/null; then
    dbus-run-session -- omadeb-theme-set vscode-dark
  else
    omadeb-theme-set vscode-dark
  fi
fi
mkdir -p "$CONFIG/mako" "$CONFIG/fuzzel" "$CONFIG/btop/themes"
ln -sfn "$CONFIG/omadeb/current/theme/mako.ini" "$CONFIG/mako/config"
ln -sfn "$CONFIG/omadeb/current/theme/fuzzel.ini" "$CONFIG/fuzzel/fuzzel.ini"
ln -sfn "$CONFIG/omadeb/current/theme/btop.theme" "$CONFIG/btop/themes/current.theme"

# Prompt starship en bash, como Omarchy
if command -v starship >/dev/null && ! grep -q 'starship init bash' "$HOME/.bashrc"; then
  printf '\n# omadeb\neval "$(starship init bash)"\n' >>"$HOME/.bashrc"
fi

touch "$MARKER"
echo "Configuración instalada"
