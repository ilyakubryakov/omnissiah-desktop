#!/usr/bin/env bash

set -euo pipefail
[[ "$HOME" == /home/demo ]] || { echo 'Use the dedicated /home/demo container account.' >&2; exit 1; }
export PATH="$HOME/.local/bin:/usr/bin:/bin"
export QT_QPA_PLATFORM=wayland QT_QPA_PLATFORMTHEME=qt6ct
mkdir -p "$HOME/.local/state/theme" "$HOME/.cache" "$HOME/Documents/Notes/Quick Notes"
printf 'windows=soft\ngap=12\nouter=12\nmotion=smooth\ndensity=comfortable\n' > "$HOME/.local/state/theme/desktop.conf"
theme set graphite > "$HOME/theme.log" 2>&1
hyprctl reload
pipewire > "$HOME/pipewire.log" 2>&1 &
wireplumber > "$HOME/wireplumber.log" 2>&1 &
hyprpaper > "$HOME/wallpaper.log" 2>&1 &
sleep 1
root=$(readlink -f "$HOME/.local/share/omnissiah/current")
rsvg-convert "$root/assets/wallpaper.svg" -o "$HOME/.cache/demo-wallpaper.png"
theme wallpaper shared "$HOME/.cache/demo-wallpaper.png" >> "$HOME/theme.log" 2>&1
mako > "$HOME/mako.log" 2>&1 &
station-status > "$HOME/status.log" 2>&1 &
station-notebook --watch > "$HOME/notebook.log" 2>&1 &
caldash-helper > "$HOME/calendar.log" 2>&1
quickshell -n -p "$HOME/.config/quickshell/station.qml" > "$HOME/panel.log" 2>&1 &
quickshell -n -p "$HOME/.config/quickshell/cheat.qml" > "$HOME/guide.log" 2>&1 &
wait
