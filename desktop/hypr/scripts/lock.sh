#!/bin/sh
# Refresh the lock-screen background to the current wallpaper, then lock.
# hyprlock.conf reads ~/.cache/hyprlock-wall (a symlink kept fresh here), so the
# lock always matches whatever hyprpaper shows (set by `theme`). Called from hypridle lock_cmd, which
# both Meta+L and idle-timeout reach via `loginctl lock-session`.

main_output=$(oninix-display output main 2>/dev/null)
wp=$(hyprctl hyprpaper listactive 2>/dev/null | awk -v prefix="$main_output: " 'index($0, prefix) == 1 { print substr($0, length(prefix) + 1); exit }')
[ -z "$wp" ] && wp=$(oninix-theme wallpaper-path 2>/dev/null)
case "$wp" in "~"*) wp="$HOME${wp#\~}" ;; esac
mkdir -p "$HOME/.cache"
[ -f "$wp" ] && ln -sfn "$wp" "$HOME/.cache/hyprlock-wall"

exec hyprlock
