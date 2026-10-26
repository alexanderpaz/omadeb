#!/usr/bin/env bash
# Listas de paquetes de Debian 13 de omadeb. Se "sourcea"; no se ejecuta.
# Un solo lugar para el instalador (install.sh) y para post-install.sh.

# Solo para compilar los .deb de Hyprland (packaging/build-debs.sh). No van al sistema final.
BUILD_DEPS=(
  git build-essential gcc-14 g++-14 cmake meson ninja-build pkg-config gettext curl
  dpkg-dev rsync
  libgtest-dev libpixman-1-dev libpugixml-dev libzip-dev libcairo2-dev librsvg2-dev
  libtomlplusplus-dev libpango1.0-dev libjpeg-dev libwebp-dev libmagic-dev libpng-dev
  libheif-dev libjxl-dev libseat-dev libinput-dev libwayland-dev wayland-protocols
  libdrm-dev libgbm-dev libudev-dev libdisplay-info-dev hwdata libegl-dev libgles-dev
  libgl-dev libxkbcommon-dev uuid-dev libxcursor-dev libglib2.0-dev libre2-dev
  libxcb1-dev libxcb-render0-dev libxcb-xfixes0-dev libxcb-icccm4-dev
  libxcb-composite0-dev libxcb-res0-dev libxcb-errors-dev libudis86-dev
  libsdbus-c++-dev libpam0g-dev libpipewire-0.3-dev libspa-0.2-dev
  qt6-base-dev qt6-wayland-dev
)

# Sistema: herramientas del día a día, red y periféricos.
SYSTEM=(
  sudo openssh-client git curl wget nano less man-db bash-completion unzip jq rsync
  ca-certificates gnupg xz-utils fontconfig xdg-utils xdg-user-dirs
  dbus-user-session libglib2.0-bin dconf-gsettings-backend polkitd
  network-manager network-manager-gnome blueman bluez
  # Wi-Fi: NetworkManager necesita wpasupplicant, y firmware-linux no incluye estos firmware.
  wpasupplicant firmware-iwlwifi firmware-realtek firmware-atheros firmware-brcm80211 rfkill
  pipewire pipewire-pulse wireplumber libspa-0.2-bluetooth pavucontrol pamixer playerctl
  brightnessctl wlr-randr
)

# Escritorio Hyprland (sin Hyprland: ese viene en el .deb de omadeb).
DESKTOP=(
  xwayland mate-polkit gnome-keyring xdg-desktop-portal xdg-desktop-portal-gtk
  waybar mako-notifier libnotify-bin swayosd fuzzel swaybg
  alacritty btop fastfetch starship eza zoxide fzf bat ripgrep fd-find neovim lazygit
  grim slurp swappy wl-clipboard cliphist wf-recorder
  fonts-jetbrains-mono fonts-noto-color-emoji fonts-font-awesome yaru-theme-icon
  adwaita-icon-theme gnome-themes-extra
  imv mpv firefox-esr
)

# Archivos y NAS (smb://, sftp://, nfs://) sin GNOME.
FILES=(
  thunar thunar-archive-plugin thunar-volman tumbler file-roller
  gvfs gvfs-backends gvfs-fuse cifs-utils nfs-common avahi-daemon
)

# Herramientas de desarrollo (Claude CLI, Codex CLI y VS Code se instalan en devtools).
DEV=(nodejs npm build-essential)
