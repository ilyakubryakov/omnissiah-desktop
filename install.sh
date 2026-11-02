#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
if ! command -v python3 >/dev/null; then
    printf '%s\n' 'Python 3.11+ is required. Install python (pacman) or python3 (apt/dnf) first.' >&2
    exit 1
fi
exec python3 installer.py "$@"
