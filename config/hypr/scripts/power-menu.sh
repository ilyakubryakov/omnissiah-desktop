#!/usr/bin/env bash

set -euo pipefail

choice=$(printf '%s\n' lock logout suspend reboot poweroff | fuzzel --dmenu --prompt 'power > ' --lines 5) || exit 0
case "$choice" in
lock) loginctl lock-session ;;
logout) uwsm stop ;;
suspend) systemctl suspend ;;
reboot) systemctl reboot ;;
poweroff) systemctl poweroff ;;
esac
