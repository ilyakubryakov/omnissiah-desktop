#!/bin/sh

set -eu
unit=station-keep-awake.service
if systemctl --user is-active --quiet "$unit"; then
    systemctl --user stop "$unit"
    notify-send -a "Keep awake" "Off" "Idle lock is back"
else
    systemctl --user start "$unit"
    notify-send -a "Keep awake" "On" "Idle lock paused; manual and suspend locks remain active"
fi
