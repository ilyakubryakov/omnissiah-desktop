#!/usr/bin/env bash
set -euo pipefail
[[ "$HOME" == /home/demo ]] || exit 1
pipewire-pulse > "$HOME/pulse.log" 2>&1 &
sleep 1
pactl load-module module-null-sink sink_name=demo-speakers sink_properties=device.description=Demo-Speakers
pactl load-module module-remap-source master=demo-speakers.monitor source_name=demo-microphone source_properties=device.description=Demo-Microphone
pactl set-default-sink demo-speakers
pactl set-default-source demo-microphone
pactl set-sink-volume demo-speakers 45%
pactl set-source-volume demo-microphone 70%
