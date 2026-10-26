#!/usr/bin/env bash
# omadeb — instalador mínimo de Debian 13 + Hyprland, al estilo de Arch.
#
# Ejecútalo como root desde un Debian live (o cualquier Debian) con red:
#
#   git clone https://github.com/alexanderpaz/omadeb && cd omadeb && sudo ./install.sh
#
# El .deb de Hyprland se baja del último Release de GitHub, o se toma de packaging/out/
# (ver packaging/build-debs.sh), o de la URL en OMADEB_DEB_URL. Registro en /var/log/omadeb-install.log
set -euo pipefail

OMADEB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=install/lib.sh
source "$OMADEB/install/lib.sh"
# shellcheck source=install/disk.sh
source "$OMADEB/install/disk.sh"

[[ $EUID -eq 0 ]] || die "Ejecútalo como root (sudo ./install.sh)."
[[ $(dpkg --print-architecture) == amd64 ]] || die "Solo amd64."
exec > >(tee -a /var/log/omadeb-install.log) 2>&1
trap 'warn "La instalación falló. Revisa /var/log/omadeb-install.log. Puede haber montajes en /mnt (umount -R /mnt)."' ERR

SUITE=trixie
MIRROR="${OMADEB_MIRROR:-http://deb.debian.org/debian}"

# --- Hyprland .deb -----------------------------------------------------------------
DEBS="$(mktemp -d)"
shopt -s nullglob
local_debs=("$OMADEB"/packaging/out/*.deb)
if (( ${#local_debs[@]} )); then
  cp "${local_debs[@]}" "$DEBS/"
else
  url="${OMADEB_DEB_URL:-https://github.com/alexanderpaz/omadeb/releases/latest/download/omadeb-hyprland_amd64.deb}"
  curl -fL --retry 3 -o "$DEBS/omadeb-hyprland.deb" "$url" ||
    die "No pude bajar $url. Publica un Release o construye el .deb con packaging/build-debs.sh."
fi

# --- Herramientas del live ------------------------------------------------------------
step "Preparando herramientas"
# El live puede traer el USB/DVD como fuente de apt ("deb cdrom:"): se descarta, todo viene de la red.
sed -i 's/^\(deb cdrom:\)/# \1/' /etc/apt/sources.list 2>/dev/null || true
if ! grep -rqsE '^deb +(\[[^]]*\] *)?https?://' /etc/apt/sources.list /etc/apt/sources.list.d/; then
  echo "deb $MIRROR $SUITE main non-free-firmware" >/etc/apt/sources.list
fi
apt-get update -qq
apt-get install -y -qq mmdebstrap gdisk dosfstools e2fsprogs parted debian-archive-keyring >/dev/null

# --- Preguntas mínimas ----------------------------------------------------------------
step "Configuración"
[[ -d /sys/firmware/efi ]] && UEFI=true || UEFI=false
info "Arranque: $($UEFI && echo UEFI || echo BIOS)"
lsblk -dpno NAME,SIZE,MODEL | grep -v -E '^/dev/(loop|sr|ram|zram)'
ask DISK     "Disco de destino (se borrará)" ""
[[ -n $DISK ]] || die "Falta el disco."
ask HOSTNAME "Nombre del equipo" "omadeb"
ask USERNAME "Usuario" "alexpaz"
[[ $USERNAME =~ ^[a-z_][a-z0-9_-]*$ ]] || die "Usuario no válido (minúsculas, números, - y _)."
ask_secret PASSWORD "Contraseña de $USERNAME"
ask TIMEZONE "Zona horaria" "$(cat /etc/timezone 2>/dev/null || echo UTC)"
[[ -f /usr/share/zoneinfo/$TIMEZONE ]] || die "Zona horaria desconocida: $TIMEZONE"
ask LOCALE   "Locale" "en_US.UTF-8"
ask KEYMAP   "Distribución de teclado (us, es, latam...)" "us"
ask SWAP_GIB "Swap en GiB (0 = sin swap)" "4"
[[ $SWAP_GIB =~ ^[0-9]+$ ]] || die "Swap debe ser un número."

# Red del sistema nuevo: obligatoria para poder usarlo tras el reinicio.
WIFI_SSID="" WIFI_PASS=""
if compgen -G '/sys/class/net/*/wireless' >/dev/null; then
  ask WIFI_SSID "Wi-Fi (SSID) para el sistema nuevo (vacío = solo cable)" ""
  if [[ -n $WIFI_SSID ]]; then ask_secret WIFI_PASS "Contraseña del Wi-Fi"; fi
fi

disk_guard
disk_partition
disk_mount

# --- Sistema base ---------------------------------------------------------------------
step "Instalando el sistema base (mmdebstrap)"
cpu_ucode=intel-microcode
grep -q AuthenticAMD /proc/cpuinfo && cpu_ucode=amd64-microcode
bootloader=grub-pc
$UEFI && bootloader="grub-efi-amd64,shim-signed,efibootmgr"
include="systemd-sysv,dbus,linux-image-amd64,initramfs-tools,locales,tzdata,sudo,ca-certificates,curl,gnupg,apt-utils,kmod,udev,iproute2,iputils-ping,firmware-linux,$cpu_ucode,$bootloader"
mmdebstrap --variant=minbase --components="main non-free-firmware" --include="$include" \
  "$SUITE" /mnt "$MIRROR"
disk_mount_esp

cat >/mnt/etc/apt/sources.list <<APT
deb $MIRROR $SUITE main non-free-firmware
deb $MIRROR $SUITE-updates main non-free-firmware
deb http://security.debian.org/debian-security $SUITE-security main non-free-firmware
APT
disk_fstab

# --- Chroot: configuración, paquetes, escritorio ---------------------------------------
step "Configurando el sistema nuevo"
mkdir -p /mnt/root/omadeb /mnt/root/debs
cp -a "$OMADEB/." /mnt/root/omadeb/
rm -rf /mnt/root/omadeb/.git /mnt/root/omadeb/packaging/out /mnt/root/omadeb/packaging/stage
cp "$DEBS"/*.deb /mnt/root/debs/
cp -L /etc/resolv.conf /mnt/etc/resolv.conf
(
  umask 077
  {
    printf 'HOSTNAME=%q\nUSERNAME=%q\nPASSWORD=%q\nTIMEZONE=%q\nLOCALE=%q\nKEYMAP=%q\nDISK=%q\nUEFI=%s\n' \
      "$HOSTNAME" "$USERNAME" "$PASSWORD" "$TIMEZONE" "$LOCALE" "$KEYMAP" "$DISK" "$UEFI"
  } >/mnt/root/omadeb.env
)
for d in dev dev/pts proc sys run; do
  mount --bind "/$d" "/mnt/$d"
  mount --make-rslave "/mnt/$d"   # que desmontar aquí no afecte al host
done
$UEFI && mount -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars 2>/dev/null || true

chroot /mnt /bin/bash /root/omadeb/install/chroot.sh

# --- Red del sistema nuevo ------------------------------------------------------------------
step "Configurando la red del sistema nuevo"
nm_dir=/mnt/etc/NetworkManager/system-connections
mkdir -p "$nm_dir"
# Conexiones guardadas en el live (si usa NetworkManager).
cp -a /etc/NetworkManager/system-connections/. "$nm_dir/" 2>/dev/null || true
if [[ -n $WIFI_SSID ]]; then
  nm_uuid="$(cat /proc/sys/kernel/random/uuid)"
  (
    umask 077
    cat >"$nm_dir/omadeb-wifi.nmconnection" <<NM
[connection]
id=$WIFI_SSID
uuid=$nm_uuid
type=wifi
autoconnect=true

[wifi]
mode=infrastructure
ssid=$WIFI_SSID

[wifi-security]
key-mgmt=wpa-psk
psk=$WIFI_PASS

[ipv4]
method=auto

[ipv6]
method=auto
NM
  )
fi
chmod 600 "$nm_dir"/* 2>/dev/null || true
chown -R root:root "$nm_dir"
info "Ethernet: DHCP automático. Wi-Fi: ${WIFI_SSID:-no configurado (usa nmtui)}."

# --- Limpieza ------------------------------------------------------------------------------
step "Terminando"
rm -rf /mnt/root/omadeb /mnt/root/debs
rm -f /mnt/etc/resolv.conf            # NetworkManager lo recrea al arrancar
umount -R /mnt
(( SWAP_GIB > 0 )) && swapoff "$(part "$DISK" 3)" || true
step "¡Listo! Reinicia y retira el medio de instalación."
