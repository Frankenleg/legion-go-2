#!/usr/bin/env bash
# Remove the Legion Go 2 OLED brightness-slider profile installed by install.sh.
# https://github.com/Frankenleg/legion-go-2/tree/main/steamos/brightness-slider
set -euo pipefail

TAG="brightness-slider-v1.0.0"
MARKER="-- legion-go-2 brightness-slider profile: https://github.com/Frankenleg/legion-go-2"
DEST="$HOME/.config/gamescope/scripts/lenovo.legiongo2.oled.lua"

# id -u rather than $EUID so the tests can stub it.
if [[ "$(id -u)" == 0 ]]; then
    printf 'Not removed: run this without sudo.\n' >&2
    exit 1
fi
if [[ ! -e "$DEST" ]]; then
    printf 'The brightness-slider profile is not installed. Nothing to remove.\n'
    exit 0
fi
if [[ "$(head -n 1 "$DEST")" != "$MARKER" ]]; then
    printf 'Not removed: %s was not installed by this fix, so it was left in place.\n' "$DEST" >&2
    exit 1
fi
rm -f "$DEST"
printf 'Removed the brightness-slider profile (uninstaller %s).\n' "$TAG"
printf 'Double-click "Return to Gaming Mode" on the desktop to finish.\n'
