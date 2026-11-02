#!/usr/bin/env bash

set -euo pipefail
[[ $(id -u) != 0 ]] || { echo 'Run as your desktop user, not root.' >&2; exit 1; }
[[ -r /etc/os-release ]] || { echo 'This installer is for Linux.' >&2; exit 1; }
. /etc/os-release
case "$ID" in arch|cachyos|ubuntu|fedora) ;; *) echo 'Unsupported distro. Use Arch, CachyOS, Ubuntu or Fedora.' >&2; exit 1 ;; esac
if ! command -v git >/dev/null || ! command -v python3 >/dev/null; then
    case "$ID" in
        arch|cachyos) sudo pacman -Syu --needed git python ;;
        ubuntu) sudo apt-get update; sudo apt-get install git python3 ;;
        fedora) sudo dnf install git python3 ;;
    esac
fi
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
git clone --depth 1 --branch main https://github.com/ilyakubryakov/omnissiah-desktop.git "$work/source"
bash "$work/source/install.sh" "$@"
