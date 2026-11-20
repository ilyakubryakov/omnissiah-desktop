#!/bin/sh
# Grab something off the screen into the clipboard.
#   capture.sh colour   pick a pixel's colour (hex)
#   capture.sh text     OCR a region (English and Russian)
#   capture.sh qr       decode a QR code in a region

case "$1" in
colour)
    hyprpicker -a -f hex
    ;;
text)
    geom=$(slurp) || exit 0
    text=$(grim -g "$geom" - | tesseract -l eng+rus - - 2>/dev/null)
    [ -n "$text" ] || { notify-send -a Capture "No text found"; exit 1; }
    printf '%s' "$text" | wl-copy
    notify-send -a Capture "Text copied" "$(printf '%s' "$text" | head -c 120)"
    ;;
qr)
    geom=$(slurp) || exit 0
    code=$(grim -g "$geom" - | zbarimg --raw -q - 2>/dev/null)
    [ -n "$code" ] || { notify-send -a Capture "No QR code found"; exit 1; }
    printf '%s' "$code" | wl-copy
    notify-send -a Capture "QR copied" "$code"
    ;;
*)
    echo "usage: capture.sh colour|text|qr" >&2
    exit 2
    ;;
esac
