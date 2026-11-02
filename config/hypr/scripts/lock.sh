#!/bin/sh

main_output=$("$HOME/.local/bin/station-display" output main 2>/dev/null)
wp=$(hyprctl hyprpaper listactive 2>/dev/null | awk -v prefix="$main_output: " 'index($0, prefix) == 1 { print substr($0, length(prefix) + 1); exit }')
[ -z "$wp" ] && wp=$("$HOME/.local/bin/theme" wallpaper-path 2>/dev/null)
case "$wp" in "~"*) wp="$HOME${wp#\~}" ;; esac
mkdir -p "$HOME/.cache"
[ -f "$wp" ] && ln -sfn "$wp" "$HOME/.cache/hyprlock-wall"

exec hyprlock
