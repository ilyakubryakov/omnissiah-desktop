#!/bin/sh

set -eu
conf="${XDG_STATE_HOME:-$HOME/.local/state}/station/idle.conf"
out="${XDG_RUNTIME_DIR:?}/hypridle.conf"

if [ "${STATION_LAPTOP:-}" = 1 ]; then lock=5 screen=6 suspend=0; else lock=20 screen=0 suspend=0; fi
if [ -r "$conf" ]; then
    while IFS='=' read -r key value; do
        case "$value" in ''|*[!0-9]*) continue ;; esac
        [ "$value" -le 720 ] || continue
        case "$key" in lock) lock=$value ;; screen) screen=$value ;; suspend) suspend=$value ;; esac
    done < "$conf"
fi

dpms() { printf "hyprctl eval 'hl.dispatch(hl.dsp.dpms({ action = \"%s\" }))'" "$1"; }
{
    printf 'general {\n    ignore_systemd_inhibit = false\n'
    printf '    lock_cmd = pidof hyprlock || ~/.config/hypr/scripts/lock.sh\n'
    printf '    before_sleep_cmd = loginctl lock-session\n'
    printf '    after_sleep_cmd = %s\n}\n' "$(dpms enable)"
    [ "$lock" -gt 0 ] && printf 'listener {\n    timeout = %s\n    on-timeout = loginctl lock-session\n}\n' $((lock * 60))
    [ "$screen" -gt 0 ] && printf 'listener {\n    timeout = %s\n    on-timeout = %s\n    on-resume = %s\n}\n' \
        $((screen * 60)) "$(dpms disable)" "$(dpms enable)"
    [ "$suspend" -gt 0 ] && printf 'listener {\n    timeout = %s\n    on-timeout = systemctl suspend\n}\n' $((suspend * 60))
    :
} > "$out.tmp"
mv "$out.tmp" "$out"
exec hypridle -c "$out"
