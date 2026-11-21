#!/usr/bin/env bash
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
    if [[ "$confirmation" == 'Log out' ]]; then
        if [[ ${ONINIX_LAYER_DIRECT:-0} == 1 ]]; then
            hyprctl dispatch 'hl.dsp.exit()'
        else
            uwsm stop
        fi
    fi
    ;;
suspend) systemctl suspend ;;
reboot) systemctl reboot ;;
poweroff) systemctl poweroff ;;
esac
