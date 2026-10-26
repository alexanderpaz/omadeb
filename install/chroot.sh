#!/usr/bin/env bash
# Se ejecuta DENTRO del sistema nuevo (chroot desde install.sh). Lee /root/omadeb.env.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8

# shellcheck disable=SC1091
source /root/omadeb.env
OMADEB_SRC=/root/omadeb          # copia del repo traída por install.sh
USER_HOME="/home/$USERNAME"
apt_install() { apt-get install -y --no-install-recommends "$@"; }

printf '\n\e[1;35m━━ %s\e[0m\n' "Configuración del sistema"
# --- Zona horaria, locale, teclado, hostname ----------------------------------
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
echo "$TIMEZONE" >/etc/timezone
sed -i "s/^# *\($LOCALE \)/\1/" /etc/locale.gen
grep -q "^$LOCALE " /etc/locale.gen || echo "$LOCALE UTF-8" >>/etc/locale.gen
locale-gen
echo "LANG=$LOCALE" >/etc/default/locale
echo "$HOSTNAME" >/etc/hostname
printf '127.0.0.1\tlocalhost\n127.0.1.1\t%s\n::1\tlocalhost ip6-localhost ip6-loopback\n' "$HOSTNAME" >/etc/hosts

# --- Paquetes ------------------------------------------------------------------
printf '\n\e[1;35m━━ %s\e[0m\n' "Paquetes"
# shellcheck disable=SC1091
source "$OMADEB_SRC/install/packages.list.sh"
apt-get update
# El teclado (consola y escritorio) debe quedar fijado ANTES de instalar el resto.
echo "keyboard-configuration keyboard-configuration/layoutcode string $KEYMAP" | debconf-set-selections
apt_install keyboard-configuration console-setup kbd
apt_install "${SYSTEM[@]}" "${DESKTOP[@]}" "${FILES[@]}" "${DEV[@]}" greetd

# Hyprland: .deb propio (packaging/build-debs.sh). apt resuelve sus dependencias.
shopt -s nullglob
debs=(/root/debs/*.deb)
if (( ${#debs[@]} )); then
  apt_install "${debs[@]}"
else
  echo "AVISO: no hay .deb de Hyprland; el sistema arrancará sin escritorio." >&2
fi

# --- VS Code (repositorio oficial de Microsoft) --------------------------------
if curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor >/usr/share/keyrings/microsoft.gpg; then
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    >/etc/apt/sources.list.d/vscode.list
  apt-get update && apt_install code || echo "AVISO: no se pudo instalar VS Code." >&2
else
  echo "AVISO: no se pudo obtener la clave de Microsoft; sin VS Code." >&2
fi

# --- Usuario ---------------------------------------------------------------------
printf '\n\e[1;35m━━ %s\e[0m\n' "Usuario $USERNAME"
groups=sudo,video,audio,input
for g in netdev plugdev bluetooth; do getent group "$g" >/dev/null && groups+=",$g"; done
useradd -m -s /bin/bash -G "$groups" "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd
passwd -l root >/dev/null          # root bloqueado: se usa sudo
shred -u /root/omadeb.env 2>/dev/null || rm -f /root/omadeb.env

# --- Teclado de la consola (login) -------------------------------------------------
printf 'XKBMODEL="pc105"\nXKBLAYOUT="%s"\nXKBVARIANT=""\nXKBOPTIONS=""\nBACKSPACE="guess"\n' "$KEYMAP" >/etc/default/keyboard
sed -i 's/^CHARMAP=.*/CHARMAP="UTF-8"/' /etc/default/console-setup 2>/dev/null || true
setupcon --save-only --force 2>/dev/null || true
systemctl enable console-setup keyboard-setup 2>/dev/null || true

# --- Inicio de sesión: greetd -> Hyprland ----------------------------------------
# agreety: login de texto simple y fiable en la consola (tuigreet falla en algunas VT/teclados).
cmd="/usr/sbin/agreety --cmd /usr/bin/Hyprland"   # agreety está en /usr/sbin, fuera del PATH de _greetd
cat >/etc/greetd/config.toml <<CFG
[terminal]
vt = 1

[default_session]
command = "$cmd"
user = "_greetd"
CFG
systemctl disable getty@tty1 2>/dev/null || true   # la VT1 es de greetd
systemctl enable greetd NetworkManager avahi-daemon bluetooth 2>/dev/null || true
systemctl --global enable pipewire pipewire-pulse wireplumber 2>/dev/null || true

# --- Arranque (GRUB) ---------------------------------------------------------------
printf '\n\e[1;35m━━ %s\e[0m\n' "GRUB"
if [[ $UEFI == true ]]; then
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=omadeb --force-extra-removable
else
  grub-install --target=i386-pc "$DISK"
fi
update-grub

# --- Escritorio del usuario ----------------------------------------------------------
printf '\n\e[1;35m━━ %s\e[0m\n' "Escritorio de $USERNAME"
install -d -o "$USERNAME" -g "$USERNAME" "$USER_HOME/.local/share"
cp -a "$OMADEB_SRC" "$USER_HOME/.local/share/omadeb"
rm -rf "$USER_HOME/.local/share/omadeb/.git" "$USER_HOME/.local/share/omadeb/packaging/out" "$USER_HOME/.local/share/omadeb/packaging/stage"
chown -R "$USERNAME:$USERNAME" "$USER_HOME/.local"
run_user() { su - "$USERNAME" -c "$1"; }
run_user 'bash ~/.local/share/omadeb/install/configs.sh'
sed -i "s/^\( *kb_layout *= *\).*/\1$KEYMAP/" "$USER_HOME/.config/hypr/input.conf"
run_user 'bash ~/.local/share/omadeb/install/fonts.sh'     || echo "AVISO: fuentes Nerd no instaladas." >&2
run_user 'bash ~/.local/share/omadeb/install/devtools.sh'  || echo "AVISO: devtools incompleto." >&2
run_user 'xdg-user-dirs-update'                            || true
run_user 'xdg-settings set default-web-browser firefox-esr.desktop' || true
run_user 'xdg-mime default thunar.desktop inode/directory' || true
update-alternatives --set x-www-browser /usr/bin/firefox-esr 2>/dev/null || true

apt-get clean
