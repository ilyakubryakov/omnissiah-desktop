#!/usr/bin/env bash
# Power menu for the bar's power button.
set -euo pipefail

if [[ "${1:-}" == "--logout" ]]; then
    choice=logout
else
    choice=$(printf '%s\n' lock logout suspend reboot poweroff | fuzzel --dmenu --prompt 'power > ' --lines 5) || exit 0
fi
case "$choice" in
lock) loginctl lock-session ;;
logout)
    confirmation=$(printf '%s\n' Cancel 'Log out' | fuzzel --dmenu --prompt 'Log out? > ' --lines 2) || exit 0
    [[ "$confirmation" == 'Log out' ]] && uwsm stop
    ;;
suspend) systemctl suspend ;;
reboot) systemctl reboot ;;
poweroff) systemctl poweroff ;;
esac
