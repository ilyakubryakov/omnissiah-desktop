#!/bin/sh
# Focus the first window whose class matches $1 (a case-insensitive regex), or
# start the rest of the arguments (a .desktop id or a command) when nothing
# matches. Used by the Meta+Alt keys, the bar launchers and the Xeneon pills.
# A visible window wins; a minimized one is restored to the current desktop.

address=$(hyprctl clients -j | jq -r --arg re "$1" '
    [.[] | select(.class | test($re; "i"))]
    | (map(select(.workspace.name != "special:minimized")) | sort_by(.focusHistoryID) | first)
      // (sort_by(.focusHistoryID) | first)
    | .address // empty')

if [ -n "$address" ]; then
    hyprctl eval "require(\"minimize\").show(\"address:$address\")" >/dev/null
else
    shift
    exec uwsm app -- "$@"
fi
