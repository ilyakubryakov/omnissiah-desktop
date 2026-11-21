#!/bin/sh
set -u

unit=oninix-screenrecord.service
active() { systemctl --user is-active --quiet "$unit"; }
stop() { active && systemctl --user stop --no-block "$unit"; }

case "${1:-}" in
    status) active; exit $? ;;
    stop) stop; exit $? ;;
esac
if stop; then exit 0; fi

conf="${XDG_STATE_HOME:-$HOME/.local/state}/oninix/capture.conf"
audio=yes mic=no pointer=no
if [ -r "$conf" ]; then
    while IFS='=' read -r key value; do
        case "$key=$value" in
            audio=yes|audio=no) audio=$value ;;
            mic=yes|mic=no) mic=$value ;;
            pointer=yes|pointer=no) pointer=$value ;;
        esac
    done < "$conf"
fi

case "${1:-}" in
    region) geom=$(slurp) || exit 0 ;;
    video) geom=$(slurp -o -d) || exit 0 ;;
    *) geom= ;;
esac
monitor=$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name')
dir="$HOME/Videos/Screencasts"
mkdir -p "$dir" || exit 1
out="$dir/Screencast $(date '+%Y-%m-%d %H.%M.%S.%N').mp4"

if command -v gpu-screen-recorder >/dev/null 2>&1; then
    if [ -n "$geom" ]; then
        region=$(printf '%s\n' "$geom" | awk '{ split($1, start, ","); print $2 "+" start[1] "+" start[2] }')
        set -- -w region -region "$region"
    else
        set -- -w "$monitor"
    fi
    set -- gpu-screen-recorder "$@" -f 60 -k h264 -cursor "$pointer" -o "$out"
    sources=
    [ "$audio" = yes ] && sources=default_output
    [ "$mic" = yes ] && sources="${sources:+$sources|}default_input"
    [ -z "$sources" ] || set -- "$@" -a "$sources"
else
    if [ "$pointer" = yes ] || { [ "$audio" = yes ] && [ "$mic" = yes ]; }; then
        notify-send -a Screencast "Capture options unavailable" "Turn off Show pointer and select one audio source for software recording."
        exit 1
    fi
    if [ -n "$geom" ]; then
        set -- -g "$geom"
    else
        set -- -o "$monitor"
    fi
    set -- wf-recorder --no-dmabuf -f "$out" "$@"
    if [ "$audio" = yes ]; then
        sink=$(wpctl inspect @DEFAULT_AUDIO_SINK@ | awk -F '"' '/node.name = / {print $2; exit}')
        if [ -n "$sink" ]; then set -- "$@" "--audio=$sink.monitor"; fi
    elif [ "$mic" = yes ]; then
        source=$(wpctl inspect @DEFAULT_AUDIO_SOURCE@ | awk -F '"' '/node.name = / {print $2; exit}')
        if [ -n "$source" ]; then set -- "$@" "--audio=$source"; fi
    fi
fi

notify-send -a Screencast "Recording" "Press the capture key again to stop"
if systemd-run --user --quiet --wait --collect --unit="$unit" --service-type=exec \
    --property=PartOf=graphical-session.target --property=KillSignal=SIGINT -- "$@" && [ -s "$out" ]; then
    action=$(notify-send -a Screencast -A default="Open folder" "Recording saved" "${out##*/}")
    if [ "$action" = default ]; then xdg-open "$dir"; fi
else
    notify-send -a Screencast "Recording failed" "See the oninix-screenrecord journal"
    exit 1
fi
