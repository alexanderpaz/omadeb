#!/usr/bin/env bash
# Particionado y montaje en /mnt. Requiere lib.sh y las variables DISK, SWAP_GIB, UEFI.
#   UEFI: 1 = EFI (1 GiB, vfat)   BIOS: 1 = bios_boot (1 MiB)
#   2 = raíz ext4 (resto)         3 = swap (opcional, al final)

disk_guard() {
  [[ -b $DISK ]] || die "$DISK no es un disco."
  # Nunca tocar el medio del que arrancó el live (no hace falta sacarlo: elige otro disco).
  local m
  while read -r m; do
    case $m in
      /|/run/live*|/lib/live*|/usr/lib/live*|/cdrom*|/run/archiso*)
        die "$DISK es el medio de instalación (montado en $m). Elige otro disco." ;;
    esac
  done < <(lsblk -nrpo MOUNTPOINTS "$DISK" | tr ' ' '\n' | grep -v '^$')
  lsblk -o NAME,SIZE,FSTYPE,LABEL,MODEL "$DISK"
  warn "SE BORRARÁ TODO EL CONTENIDO DE $DISK"
  local confirm
  read -r -p "Escribe el nombre del disco ($DISK) para confirmar: " confirm
  [[ $confirm == "$DISK" ]] || die "Cancelado."
  # Particiones del disco elegido montadas o en uso (p. ej. automontaje): se sueltan.
  local p
  while read -r p; do swapoff "$p" 2>/dev/null || true; umount -R "$p" 2>/dev/null || true; done \
    < <(lsblk -nrpo NAME "$DISK" | tac)
}

disk_partition() {
  step "Particionando $DISK"
  wipefs -af "$DISK" >/dev/null
  sgdisk --zap-all "$DISK" >/dev/null
  if $UEFI; then
    sgdisk -n 1:0:+1G -t 1:ef00 -c 1:EFI "$DISK" >/dev/null
  else
    sgdisk -n 1:0:+1M -t 1:ef02 -c 1:BIOSBOOT "$DISK" >/dev/null
  fi
  if (( SWAP_GIB > 0 )); then
    sgdisk -n "2:0:-${SWAP_GIB}G" -t 2:8300 -c 2:root "$DISK" >/dev/null
    sgdisk -n 3:0:0 -t 3:8200 -c 3:swap "$DISK" >/dev/null
  else
    sgdisk -n 2:0:0 -t 2:8300 -c 2:root "$DISK" >/dev/null
  fi
  partprobe "$DISK"; udevadm settle
  sleep 1

  $UEFI && mkfs.vfat -F32 -n EFI "$(part "$DISK" 1)" >/dev/null
  mkfs.ext4 -F -L omadeb "$(part "$DISK" 2)" >/dev/null
  if (( SWAP_GIB > 0 )); then mkswap -L swap "$(part "$DISK" 3)" >/dev/null; fi
}

disk_mount() {
  mount "$(part "$DISK" 2)" /mnt
  if $UEFI; then
    mkdir -p /mnt/boot/efi
    mount "$(part "$DISK" 1)" /mnt/boot/efi
  fi
  if (( SWAP_GIB > 0 )); then swapon "$(part "$DISK" 3)"; fi
}

disk_fstab() {
  local root esp swap
  root="$(blkid -s UUID -o value "$(part "$DISK" 2)")"
  {
    echo "# /etc/fstab — generado por omadeb"
    echo "UUID=$root  /          ext4  defaults,noatime  0 1"
    if $UEFI; then
      esp="$(blkid -s UUID -o value "$(part "$DISK" 1)")"
      echo "UUID=$esp   /boot/efi  vfat  umask=0077        0 2"
    fi
    if (( SWAP_GIB > 0 )); then
      swap="$(blkid -s UUID -o value "$(part "$DISK" 3)")"
      echo "UUID=$swap  none       swap  sw                0 0"
    fi
  } >/mnt/etc/fstab
}
