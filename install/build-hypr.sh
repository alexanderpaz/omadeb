#!/usr/bin/env bash
# Compila Hyprland y su ecosistema desde el código fuente en /usr/local.
#
# Versiones fijadas: Hyprland v0.51.1 es la última que compila contra las
# librerías de Debian 13 (las 0.52+ exigen libxkbcommon >= 1.11; Debian trae 1.7).
# Se parchean algunos usos de C++23/26 que GCC 14 no soporta.
# Cada librería está fijada a la release compatible con esa versión.
set -euo pipefail

# OMADEB_PREFIX=/usr y OMADEB_STAGE=<dir> lo usa packaging/build-debs.sh: además de instalar
# en el sistema de compilación, deja una copia en <dir> para empaquetarla.
PREFIX="${OMADEB_PREFIX:-/usr/local}"
STAGE="${OMADEB_STAGE:-}"
BUILD_DIR="${OMADEB_BUILD_DIR:-$HOME/.cache/omadeb-build}"
JOBS="$(nproc)"

export CC=gcc-14 CXX=g++-14
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig:${PKG_CONFIG_PATH:-}"
export CMAKE_PREFIX_PATH="$PREFIX"

# nombre  tag  sistema-de-build
COMPONENTS=(
  "hyprwayland-scanner         v0.4.5   cmake"
  "hyprutils                   v0.10.4  cmake"
  "hyprlang                    v0.6.7   cmake"
  "hyprcursor                  v0.1.13  cmake"
  "hyprgraphics                v0.4.0   cmake"
  "aquamarine                  v0.10.0  cmake"
  "hyprland-protocols          v0.7.0   meson"
  "Hyprland                    v0.51.1  cmake"
  "hyprlock                    v0.9.2   cmake"
  "hypridle                    v0.1.7   cmake"
  "xdg-desktop-portal-hyprland v1.3.11  cmake"
  "hyprpicker                  v0.4.5   cmake"
  "hyprland-qt-support         v0.1.0   cmake"
  "hyprland-qtutils            v0.1.4   cmake"
)

WAYLAND_PROTOCOLS_VERSION=1.45

step() { printf '\n\e[1;34m==>\e[0m \e[1m%s\e[0m\n' "$*"; }

already_installed() {
  # $1 = marcador, $2 = versión
  [[ -f "$BUILD_DIR/.done-$1-$2" ]]
}

mark_installed() { touch "$BUILD_DIR/.done-$1-$2"; }

build_wayland_protocols() {
  local v=$WAYLAND_PROTOCOLS_VERSION
  already_installed wayland-protocols "$v" && { echo "wayland-protocols $v ya instalado"; return; }
  step "wayland-protocols $v"
  cd "$BUILD_DIR"
  rm -rf "wayland-protocols-$v"
  curl -fsSL "https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/$v/downloads/wayland-protocols-$v.tar.xz" | tar xJ
  cd "wayland-protocols-$v"
  meson setup build --prefix="$PREFIX" --buildtype=release -Dtests=false
  ninja -C build
  sudo ninja -C build install
  mark_installed wayland-protocols "$v"
}

build_component() {
  local name=$1 tag=$2 system=$3
  already_installed "$name" "$tag" && { echo "$name $tag ya instalado"; return; }
  step "$name $tag"
  cd "$BUILD_DIR"
  rm -rf "$name"
  git clone --quiet --depth 1 --branch "$tag" --recurse-submodules --shallow-submodules \
    "https://github.com/hyprwm/$name.git" "$name"
  cd "$name"

  local extra=()
  case $name in
    Hyprland)
      extra=(-DNO_HYPRPM=ON -DNO_UWSM=ON)
      # GCC 14 no tiene string + string_view (C++26): convertir a std::string.
      sed -i 's|instanceSignature + "/" + filename;|instanceSignature + "/" + std::string{filename};|' hyprctl/main.cpp
      # GCC 14 tampoco soporta #embed (C23/C++26): generar los bytes con od.
      od -An -v -tu1 example/hyprland.conf | sed 's/[[:space:]]\+/,/g; s/^,//; s/$/,/' > src/config/exampleConfigBytes.inc
      sed -i 's|^#embed .*|#include "exampleConfigBytes.inc"|' src/config/defaultConfig.hpp
      sed -i 's|requestedModes.insert_range(requestedModes.end(), sortedModes \| std::views::reverse);|requestedModes.insert(requestedModes.end(), sortedModes.rbegin(), sortedModes.rend());|' src/helpers/Monitor.cpp
      sed -i 's|return m_connection ? \*m_connection : nullptr;|return m_connection ? static_cast<xcb_connection_t*>(*m_connection) : nullptr;|' src/xwayland/XWM.hpp
      ;;
    hyprutils|hyprlang|hyprgraphics|aquamarine|hyprland-qt-support|hyprland-qtutils) extra=(-DBUILD_TESTING=OFF) ;;
  esac

  if [[ $system == meson ]]; then
    meson setup build --prefix="$PREFIX" --buildtype=release
    ninja -C build
    sudo ninja -C build install
    [[ -n $STAGE ]] && DESTDIR="$STAGE" ninja -C build install
  else
    cmake -S . -B build -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX="$PREFIX" \
      -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
      "${extra[@]}"
    cmake --build build -j "$JOBS"
    sudo cmake --install build
    [[ -n $STAGE ]] && DESTDIR="$STAGE" cmake --install build
  fi
  sudo ldconfig
  mark_installed "$name" "$tag"
}

install_session_files() {
  # Con prefijo /usr (paquete .deb) Hyprland ya instala sesión y portal donde toca.
  [[ $PREFIX == /usr ]] && return
  step "Integración con el gestor de sesión y los portales"
  # GDM y xdg-desktop-portal solo buscan en /usr/share en Debian.
  sudo install -Dm644 /dev/stdin /usr/share/wayland-sessions/hyprland.desktop <<EOF
[Desktop Entry]
Name=Hyprland
Comment=omadeb — Hyprland al estilo Omarchy
Exec=$PREFIX/bin/Hyprland
Type=Application
DesktopNames=Hyprland
Keywords=tiling;wayland;compositor;
EOF
  # Evita que aparezcan dos entradas "Hyprland" en el login.
  sudo rm -f "$PREFIX/share/wayland-sessions/hyprland.desktop"

  if [[ -f $PREFIX/share/xdg-desktop-portal/portals/hyprland.portal ]]; then
    sudo install -Dm644 "$PREFIX/share/xdg-desktop-portal/portals/hyprland.portal" \
      /usr/share/xdg-desktop-portal/portals/hyprland.portal
  fi
}

main() {
  if [[ ${1:-} == --clean ]]; then
    rm -rf "$BUILD_DIR"
  fi
  mkdir -p "$BUILD_DIR"
  [[ -n $STAGE ]] && mkdir -p "$STAGE"
  sudo -v

  build_wayland_protocols
  for entry in "${COMPONENTS[@]}"; do
    # shellcheck disable=SC2086
    build_component $entry
  done
  install_session_files

  step "Listo: $("$PREFIX/bin/Hyprland" --version | head -1)"
}

main "$@"
