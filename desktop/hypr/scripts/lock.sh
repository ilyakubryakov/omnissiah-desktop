#!/bin/sh
set -eu

exec 9>"${XDG_RUNTIME_DIR:?}/oninix-hyprlock.lock"
flock -n 9 || exit 0

scripts=$(dirname -- "$0")
hypr=$(dirname -- "$scripts")
state=${XDG_STATE_HOME:-$HOME/.local/state}
palette=$state/theme/current/hyprlock-colors.conf
runtime=$(mktemp -d "$XDG_RUNTIME_DIR/oninix-hyprlock.XXXXXX")
trap 'rm -rf -- "$runtime"' EXIT

main_output=$(oninix-display output main 2>/dev/null || :)
wp=$(hyprctl hyprpaper listactive 2>/dev/null | awk -v prefix="$main_output: " 'index($0, prefix) == 1 { print substr($0, length(prefix) + 1); exit }')
[ -n "$wp" ] || wp=$(oninix-theme wallpaper-path 2>/dev/null || :)
case "$wp" in "~"*) wp="$HOME${wp#\~}" ;; esac

wallpaper=
if [ -f "$wp" ] && [ -r "$wp" ]; then
    wallpaper=$runtime/wallpaper
    ln -s -- "$wp" "$wallpaper"
fi

{
    printf 'source = %s/hyprlock-colors.conf\n' "$hypr"
    if [ -f "$palette" ] && [ -r "$palette" ]; then
        printf 'source = %s\n' "$palette"
    fi
    printf '$lock_wallpaper = %s\n$lock_summary = %s/lock-summary\n' "$wallpaper" "$scripts"
    printf 'source = %s/hyprlock.conf\n' "$hypr"
} > "$runtime/hyprlock.conf"

hyprlock --config "$runtime/hyprlock.conf"
