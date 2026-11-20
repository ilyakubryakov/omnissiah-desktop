#!/bin/sh
set -eu

unit=oninix-keep-awake.service
if systemctl --user is-active --quiet "$unit"; then
    systemctl --user stop "$unit"
else
    systemctl --user start "$unit"
fi
