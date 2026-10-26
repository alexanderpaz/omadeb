#!/usr/bin/env bash
# Construye el .deb `omadeb-hyprland` (Hyprland y su ecosistema, en /usr).
# Ejecútalo UNA vez en una Debian 13 limpia (VM o contenedor); el instalador solo
# necesita el .deb resultante. Tarda lo mismo que build-hypr.sh (30-60 min).
#
#   packaging/build-debs.sh            compila y empaqueta -> packaging/out/*.deb
#   packaging/build-debs.sh pack       solo empaqueta (reusa OMADEB_STAGE ya compilado)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${OMADEB_OUT:-$HERE/out}"
STAGE="${OMADEB_STAGE:-$HERE/stage}"
VERSION="${OMADEB_DEB_VERSION:-0.51.1+omadeb1}"
ARCH="$(dpkg --print-architecture)"
PKG=omadeb-hyprland

build() {
  # shellcheck source=../install/packages.list.sh
  source "$HERE/../install/packages.list.sh"
  sudo apt-get update
  sudo apt-get install -y --no-install-recommends "${BUILD_DEPS[@]}"
  rm -rf "$STAGE"
  # Las marcas de "ya instalado" no sirven aquí: el stage nuevo debe recibir TODOS los componentes.
  rm -f "${OMADEB_BUILD_DIR:-$HOME/.cache/omadeb-build}"/.done-*
  OMADEB_PREFIX=/usr OMADEB_STAGE="$STAGE" bash "$HERE/../install/build-hypr.sh"
}

pack() {
  [[ -x $STAGE/usr/bin/Hyprland ]] || { echo "No hay $STAGE/usr/bin/Hyprland: compila primero." >&2; exit 1; }
  local root work
  root="$(mktemp -d)"
  work="$(mktemp -d)"
  trap 'rm -rf "$root" "$work"' RETURN

  cp -a "$STAGE/." "$root/"
  # Solo lo necesario para ejecutar: fuera cabeceras y metadatos de compilación.
  rm -rf "$root"/usr/include "$root"/usr/lib/pkgconfig "$root"/usr/lib/*/pkgconfig \
         "$root"/usr/lib/cmake "$root"/usr/lib/*/cmake "$root"/usr/share/pkgconfig \
         "$root"/usr/share/hyprland-protocols/pkgconfig "$root"/usr/share/wayland-protocols \
         "$root"/usr/share/bash-completion "$root"/usr/share/fish "$root"/usr/share/zsh
  find "$root" -name '*.a' -delete
  # Fondos de pantalla de Hyprland (~48 MB): omadeb trae su propio fondo.
  rm -f "$root"/usr/share/hypr/wall*.png
  find "$root/usr/bin" "$root/usr/lib" -type f \( -perm -u+x -o -name '*.so*' \) \
    -exec strip --strip-unneeded {} + 2>/dev/null || true

  # Dependencias de ejecución calculadas desde los binarios (no a mano).
  mkdir -p "$work/debian"
  printf 'Source: %s\n\nPackage: %s\nArchitecture: %s\n' "$PKG" "$PKG" "$ARCH" >"$work/debian/control"
  local targets=() libdirs=()
  while IFS= read -r f; do
    file -b "$f" | grep -q ELF && targets+=("-e$f")
  done < <(find "$root/usr/bin" "$root/usr/lib" "$root/usr/libexec" -type f 2>/dev/null)
  ((${#targets[@]})) || { echo "No se encontraron binarios ELF (¿falta el paquete «file»?)." >&2; exit 1; }
  while IFS= read -r d; do libdirs+=("-l$d"); done < <(find "$root/usr/lib" -type d)
  local deps
  deps="$(cd "$work" && dpkg-shlibdeps -O --ignore-missing-info "${libdirs[@]}" "${targets[@]}" 2>/dev/null |
    sed -n 's/^shlibs:Depends=//p')"
  # Hyprland también necesita en ejecución: datos de pantallas y polkit/portales.
  # hyprland-qtutils (diálogos de Hyprland) carga QML en ejecución.
  deps="${deps:+$deps, }hwdata, xwayland, xdg-desktop-portal, qt6-wayland, qml6-module-qtquick, qml6-module-qtquick-controls, qml6-module-qtquick-layouts, qml6-module-qtquick-templates, qml6-module-qtquick-window, qml6-module-qtqml-workerscript"

  mkdir -p "$root/DEBIAN" "$OUT"
  cat >"$root/DEBIAN/control" <<CTRL
Package: $PKG
Version: $VERSION
Architecture: $ARCH
Maintainer: omadeb <noreply@github.com>
Section: x11
Priority: optional
Depends: $deps
Provides: hyprland
Conflicts: hyprland
Description: Hyprland y su ecosistema para omadeb
 Hyprland, hyprlock, hypridle, hyprpicker, hyprland-qtutils, hyprcursor y xdg-desktop-portal-hyprland,
 compilados contra Debian 13 con las versiones fijadas en install/build-hypr.sh.
CTRL
  printf '#!/bin/sh\nset -e\nldconfig\n' >"$root/DEBIAN/postinst"
  cp "$root/DEBIAN/postinst" "$root/DEBIAN/postrm"
  chmod 755 "$root/DEBIAN/postinst" "$root/DEBIAN/postrm"

  dpkg-deb --root-owner-group --build "$root" "$OUT/${PKG}_${VERSION}_${ARCH}.deb"
  echo "Listo: $OUT/${PKG}_${VERSION}_${ARCH}.deb"
}

case "${1:-all}" in
  pack) pack ;;
  all)  build; pack ;;
  *)    echo "uso: build-debs.sh [all|pack]" >&2; exit 1 ;;
esac
