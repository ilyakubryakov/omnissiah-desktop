#!/bin/sh
set -u
conf="${XDG_STATE_HOME:-$HOME/.local/state}/oninix/capture.conf"
shots="$HOME/Pictures/Screenshots"
videos="$HOME/Videos/Screencasts"
mode=region audio=yes mic=no pointer=no
if [ -r "$conf" ]; then
    while IFS='=' read -r key value; do
        case "$key=$value" in
            mode=region|mode=screen|mode=video) mode=$value ;;
            audio=yes|audio=no) audio=$value ;;
            mic=yes|mic=no) mic=$value ;;
            pointer=yes|pointer=no) pointer=$value ;;
        esac
    done < "$conf"
fi
case "${1:-}" in region|screen|video) mode=$1; shift ;; esac
save=${1:-}
stamp=$(date '+%Y-%m-%d %H.%M.%S')

if pkill -INT -f '(^|/)gpu-screen-recorder( |$)'; then
    sleep 1
    last=$(ls -t "$videos"/*.mp4 2>/dev/null | head -n 1)
    (
        action=$(notify-send -a Screencast -A default="Open folder" -A play=Play "Recording saved" "${last##*/}")
        case "$action" in
            default) xdg-open "$videos" ;;
            play) xdg-open "$last" ;;
        esac
    ) >/dev/null 2>&1 &
    exit 0
fi

windows() {
    hyprctl -j monitors | jq -r '.[].activeWorkspace.id' > "${XDG_RUNTIME_DIR:?}/shot-ws"
    hyprctl -j clients | jq -r --slurpfile ws "$XDG_RUNTIME_DIR/shot-ws" \
        '.[] | select(.workspace.id as $w | $ws | index($w)) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"'
}

if [ "$mode" = video ]; then
    geom=$(slurp -o -d -f '%wx%h+%x+%y') || exit 0
    sources=
    [ "$audio" = yes ] && sources=default_output
    [ "$mic" = yes ] && sources="${sources:+$sources|}default_input"
    mkdir -p "$videos"
    set -- -w region -region "$geom" -f 60 -k h264 -cursor "$pointer" -o "$videos/Screencast $stamp.mp4"
    [ -n "$sources" ] && set -- "$@" -a "$sources"
    notify-send -a Screencast "Recording" "Press the capture key again to stop"
    exec gpu-screen-recorder "$@"
fi

file="$XDG_RUNTIME_DIR/Screenshot $stamp.png"
cursor=
[ "$pointer" = yes ] && cursor=-c
if [ "$mode" = screen ]; then
    output=$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name')
    grim $cursor -o "$output" "$file" || exit 1
else
    geom=$(windows | slurp -d) || exit 0
    grim $cursor -g "$geom" "$file" || exit 1
fi
wl-copy --type image/png < "$file"
oninix-desktop shelf-add --copy "$file" >/dev/null 2>&1 || true

saved=
if [ "$save" = save ]; then
    mkdir -p "$shots"
    saved="$shots/${file##*/}"
    cp "$file" "$saved"
fi
(
    if [ -n "$saved" ]; then
        action=$(notify-send -a Screenshot -i "$saved" -A default=Edit -A folder="Open folder" "Screenshot saved and copied" "${saved##*/}")
    else
        action=$(notify-send -a Screenshot -i "$file" -A default=Edit -A save=Save "Screenshot copied" "Click to edit")
    fi
    case "$action" in
        default) mkdir -p "$shots"; swappy -f "${saved:-$file}" -o "$shots/${file##*/}" ;;
        save) mkdir -p "$shots"; cp "$file" "$shots/" ;;
        folder) xdg-open "$shots" ;;
    esac
    rm -f "$file"
) >/dev/null 2>&1 &
