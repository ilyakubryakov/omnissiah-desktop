#!/bin/sh
# Start or stop a screen recording with the GPU encoder (gpu-screen-recorder).
#   screenrecord.sh          the focused monitor
#   screenrecord.sh region   a region picked with slurp
# Running again stops it. Audio is whatever plays on the default output.
# Files land in ~/Videos/Screencasts; the bar shows a dot while it runs.

if pkill -INT -f '(^|/)gpu-screen-recorder( |$)'; then
    notify-send -a Screencast "Recording saved" "~/Videos/Screencasts"
    exit 0
fi

dir="$HOME/Videos/Screencasts"
mkdir -p "$dir"
out="$dir/rec-$(date +%Y%m%d-%H%M%S).mp4"

if [ "$1" = region ]; then
    geom=$(slurp -f '%wx%h+%x+%y') || exit 0
    set -- -w region -region "$geom"
else
    monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
    set -- -w "$monitor"
fi

notify-send -a Screencast "Recording" "Same key again to stop"
exec gpu-screen-recorder "$@" -f 60 -k h264 -a default_output -o "$out"
