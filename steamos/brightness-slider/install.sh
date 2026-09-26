#!/usr/bin/env bash
# Install the Legion Go 2 OLED brightness-slider profile for gamescope.
# https://github.com/Frankenleg/legion-go-2/tree/main/steamos/brightness-slider
set -euo pipefail

TAG="brightness-slider-v1.0.1"
MARKER="-- legion-go-2 brightness-slider profile: https://github.com/Frankenleg/legion-go-2"
FIXED_IN="3.16.29"
NAME="lenovo.legiongo2.oled.lua"
BASE_URL="https://raw.githubusercontent.com/Frankenleg/legion-go-2/${TAG}/steamos/brightness-slider"

# Test hooks; the defaults are the real system paths and the published file.
OS_RELEASE="${LG2_OS_RELEASE:-/etc/os-release}"
DRM_DIR="${LG2_DRM_DIR:-/sys/class/drm}"
PROFILE_URL="${LG2_PROFILE_URL:-$BASE_URL/$NAME}"
PROTOCOLS="=https"
if [[ -n "${LG2_PROFILE_URL:-}" ]]; then
    PROTOCOLS="=https,file"
fi

DEST_DIR="$HOME/.config/gamescope/scripts"
DEST="$DEST_DIR/$NAME"

stop() {
    printf '\nNot installed: %s\n' "$1" >&2
    exit 1
}

panel_matches() {
    local edid
    for edid in "$DRM_DIR"/card*-eDP-*/edid; do
        # Bytes 8-11: vendor SDC (4c 83) and product 0x4301 (little-endian 01 43).
        if [[ "$(od -An -tx1 -j8 -N4 "$edid" 2>/dev/null | tr -d ' \n')" == "4c830143" ]]; then
            return 0
        fi
    done
    return 1
}

# The whole body is in main, called on the last line, so a download cut off
# partway through curl | bash defines functions but runs nothing.
main() {
    # id -u rather than $EUID so the tests can stub it.
    if [[ "$(id -u)" == 0 ]]; then
        stop "run this without sudo. The fix goes in your own home folder."
    fi
    if ! grep -qxE 'ID="?steamos"?' "$OS_RELEASE" 2>/dev/null; then
        stop "this fix is for SteamOS, and this system is not SteamOS."
    fi
    if ! panel_matches; then
        stop "this device's screen is not the Legion Go 2 OLED panel (Samsung SDC 0x4301)."
    fi
    if ! installed="$(pacman -Q gamescope 2>/dev/null)"; then
        stop "could not find the gamescope package with pacman."
    fi
    version="${installed#gamescope }"
    if (($(vercmp "$version" "$FIXED_IN") >= 0)); then
        printf 'Your SteamOS already includes the fix (gamescope %s). Nothing to install.\n' "$version"
        exit 0
    fi

    if ! mkdir -p "$DEST_DIR" 2>/dev/null; then
        stop "could not create the folder $DEST_DIR."
    fi
    if [[ -e "$DEST" && ! -f "$DEST" ]]; then
        stop "$DEST is a folder or special file. Move it out of the way and run this again."
    fi
    if ! temporary="$(mktemp "$DEST_DIR/.$NAME.XXXXXX" 2>/dev/null)"; then
        stop "could not write to the folder $DEST_DIR."
    fi
    trap 'rm -f "$temporary"' EXIT
    if ! curl -fsSL --proto "$PROTOCOLS" -o "$temporary" "$PROFILE_URL"; then
        stop "could not download the profile from $PROFILE_URL. Check your internet connection and try again."
    fi
    if [[ "$(head -n 1 "$temporary")" != "$MARKER" ]]; then
        stop "the downloaded file is not the brightness-slider profile."
    fi

    if [[ -f "$DEST" ]] && cmp -s "$temporary" "$DEST"; then
        printf 'The brightness-slider profile (%s) is already installed.\n' "$TAG"
        exit 0
    fi
    if [[ -e "$DEST" ]]; then
        backup="$DEST.bak-$(date -u +%Y%m%dT%H%M%SZ)"
        if ! cp -p "$DEST" "$backup" 2>/dev/null; then
            rm -f "$backup"
            stop "could not save a copy of $DEST, so it was left in place."
        fi
        printf 'Saved your previous file as %s\n' "$backup"
    fi
    if ! chmod 0644 "$temporary" || ! mv -f "$temporary" "$DEST"; then
        stop "could not write $DEST."
    fi

    cat <<EOF

Installed the brightness-slider profile ($TAG).

Next:
  1. Double-click "Return to Gaming Mode" on the desktop.
  2. Open the Quick Access menu and move the brightness slider.
     The screen should get brighter and darker.

To check it later, come back to Desktop Mode and run:
  journalctl -b -t gamescope-session | grep -q "Matched vendor: SDC product: 0x4301" && echo "working" || echo "not active yet"
EOF
}

main "$@"
