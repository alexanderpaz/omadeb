#!/usr/bin/env bash
# Utilidades comunes del instalador. Se "sourcea".

step() { printf '\n\e[1;35m━━ %s\e[0m\n' "$*"; }
info() { printf '\e[1;34m==>\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33m!! %s\e[0m\n' "$*" >&2; }
die()  { printf '\e[1;31mError: %s\e[0m\n' "$*" >&2; exit 1; }

# ask VAR "Pregunta" "defecto"
ask() {
  local var=$1 prompt=$2 default=${3:-} reply
  read -r -p "$prompt${default:+ [$default]}: " reply
  printf -v "$var" '%s' "${reply:-$default}"
}

# ask_secret VAR "Pregunta" (pide dos veces)
ask_secret() {
  local var=$1 prompt=$2 a b
  while true; do
    read -r -s -p "$prompt: " a; echo
    read -r -s -p "Repite: " b; echo
    [[ -n $a && $a == "$b" ]] && break
    warn "No coinciden (o está vacía). Otra vez."
  done
  printf -v "$var" '%s' "$a"
}

part() {  # part /dev/sda 2 -> /dev/sda2 ; part /dev/nvme0n1 2 -> /dev/nvme0n1p2
  case $1 in *[0-9]) printf '%sp%s' "$1" "$2" ;; *) printf '%s%s' "$1" "$2" ;; esac
}
