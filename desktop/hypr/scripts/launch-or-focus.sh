#!/bin/sh

address=$(hyprctl clients -j | jq -r --arg re "$1" '
    [.[] | select(.class | test($re; "i"))]
    | (map(select(.workspace.name != "special:minimized")) | sort_by(.focusHistoryID) | first)
      // (sort_by(.focusHistoryID) | first)
    | .address // empty')

if [ -n "$address" ]; then
    hyprctl eval "require(\"minimize\").show(\"address:$address\")" >/dev/null
else
    shift
    exec oninix-app "$@"
fi
