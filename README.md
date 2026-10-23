# omadeb

Instalador mínimo de **Debian 13 (trixie) + Hyprland**, al estilo de la instalación de Arch:
unas pocas preguntas, sistema base con `mmdebstrap` y un escritorio ya configurado
(Hyprland, Waybar, Mako, Fuzzel, Alacritty, tema `vscode-dark`). Sin GNOME.

Incluye: ssh, git, curl, nano, sudo, NetworkManager, Bluetooth, audio, Firefox ESR,
Thunar con gvfs (SMB/NFS/SFTP para NAS), VS Code, Claude CLI, Codex CLI y herdr.

## Instalar (desde un Debian live, como root, con red)

```sh
git clone https://github.com/alexanderpaz/omadeb && cd omadeb
sudo ./install.sh
```

**Borra el disco que elijas.** El instalador pide escribir su nombre para confirmar.
Hyprland no está en Debian 13: el `.deb` precompilado se descarga del último
[Release](https://github.com/alexanderpaz/omadeb/releases). Otras opciones:
`OMADEB_DEB_URL=<url>` o un `.deb` propio en `packaging/out/`.

## Ya tengo Debian instalado

`./post-install.sh` compila Hyprland localmente (30-60 min) e instala el escritorio.

## Construir el .deb de Hyprland

`packaging/build-debs.sh` (en una Debian 13 limpia). El workflow
`.github/workflows/build-deb.yml` lo hace y lo publica al crear una etiqueta `v*`.

## Estado

Escrito y revisado, **no probado de punta a punta** en una instalación real. Prueba primero
en una VM (QEMU con OVMF para UEFI).

## Licencia

MIT, ver [LICENSE](LICENSE) y [NOTICE.md](NOTICE.md).
