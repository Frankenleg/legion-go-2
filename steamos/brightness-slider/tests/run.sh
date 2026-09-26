#!/usr/bin/env bash
# Tests for the brightness-slider fix: bash steamos/brightness-slider/tests/run.sh
set -uo pipefail

tests="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fix="$(dirname "$tests")"
profile="$fix/lenovo.legiongo2.oled.lua"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0

check() {
    local name=$1
    shift
    if "$@"; then
        printf 'ok   %s\n' "$name"
    else
        printf 'FAIL %s\n' "$name"
        failures=$((failures + 1))
    fi
}

# --- profile ---
lua_result() { lua "$tests/profile-harness.lua" "$profile" "$1"; }
check "profile parses" luac -p "$profile"
check "profile starts with the marker" test "$(head -n 1 "$profile")" == \
    "-- legion-go-2 brightness-slider profile: https://github.com/Frankenleg/legion-go-2"
check "profile registers gamma 2.2 and matches the panel" test "$(lua_result absent)" == "$(printf 'gamma22\t5000')"
check "profile leaves a shipped profile in place" test "$(lua_result shipped)" == "valve"

# --- install.sh ---
write_edid() {
    { printf '\x00\xff\xff\xff\xff\xff\xff\x00'; printf '%b' "$1"; head -c 116 /dev/zero; } \
        >"$case_dir/drm/card0-eDP-1/edid"
}

new_case() {
    case_dir="$work/$1"
    home="$case_dir/home dir"
    dest_dir="$home/.config/gamescope/scripts"
    dest="$dest_dir/lenovo.legiongo2.oled.lua"
    mkdir -p "$home" "$case_dir/drm/card0-eDP-1"
    printf 'NAME="SteamOS"\nID=steamos\n' >"$case_dir/os-release"
    write_edid '\x4c\x83\x01\x43'
    gamescope="3.16.23.6-1"
    uid=1000
    profile_url="file://$profile"
}

run_script() {
    out="$(env HOME="$home" PATH="$tests/stubs:$PATH" STUB_GAMESCOPE="$gamescope" STUB_UID="$uid" \
        LG2_OS_RELEASE="$case_dir/os-release" LG2_DRM_DIR="$case_dir/drm" LG2_PROFILE_URL="$profile_url" \
        bash "$fix/$1" 2>&1)"
    status=$?
}

contains() { [[ "$out" == *"$1"* ]]; }
absent() { [[ ! -e "$dest" ]]; }
clean_dir() { [[ ! -d "$dest_dir" || -z "$(ls -A "$dest_dir")" ]]; }

new_case install
run_script install.sh
check "install: succeeds on a Legion Go 2 OLED" test "$status" -eq 0
check "install: writes the profile" cmp -s "$profile" "$dest"
check "install: sets mode 0644" test "$(stat -c %a "$dest")" == 644
check "install: prints next steps" contains "Return to Gaming Mode"
check "install: leaves no temporary file" test "$(ls -A "$dest_dir")" == "lenovo.legiongo2.oled.lua"
run_script install.sh
check "install again: reports already installed" contains "already installed"
check "install again: makes no backup" test "$(ls -A "$dest_dir")" == "lenovo.legiongo2.oled.lua"

new_case quoted-id
printf 'ID="steamos"\n' >"$case_dir/os-release"
run_script install.sh
check "quoted os-release ID: installs" test "$status" -eq 0

new_case root
uid=0
run_script install.sh
check "root: stops" test "$status" -eq 1
check "root: explains sudo" contains "without sudo"
check "root: changes nothing" absent

new_case not-steamos
printf 'ID=arch\n' >"$case_dir/os-release"
run_script install.sh
check "not SteamOS: stops" test "$status" -eq 1
check "not SteamOS: explains" contains "not SteamOS"
check "not SteamOS: changes nothing" absent

new_case other-panel
write_edid '\x4c\x83\x02\x43'
run_script install.sh
check "other panel: stops" test "$status" -eq 1
check "other panel: explains" contains "not the Legion Go 2 OLED"
check "other panel: changes nothing" absent

new_case short-edid
printf '\x00\xff' >"$case_dir/drm/card0-eDP-1/edid"
run_script install.sh
check "short EDID: treated as another panel" contains "not the Legion Go 2 OLED"

new_case no-panel
rm -r "$case_dir/drm/card0-eDP-1"
run_script install.sh
check "no built-in panel: treated as another panel" contains "not the Legion Go 2 OLED"

new_case no-gamescope
gamescope=""
run_script install.sh
check "no gamescope: stops" test "$status" -eq 1
check "no gamescope: explains" contains "could not find the gamescope package"

new_case fixed
gamescope="3.16.29-1"
run_script install.sh
check "gamescope 3.16.29: exits cleanly" test "$status" -eq 0
check "gamescope 3.16.29: says it is not needed" contains "already includes the fix"
check "gamescope 3.16.29: changes nothing" absent

new_case download-fails
profile_url="file://$case_dir/missing.lua"
run_script install.sh
check "failed download: stops" test "$status" -eq 1
check "failed download: explains" contains "could not download"
check "failed download: no file left behind" clean_dir

new_case not-the-profile
printf '<html>rate limited</html>\n' >"$case_dir/page.html"
profile_url="file://$case_dir/page.html"
run_script install.sh
check "unexpected download: stops" test "$status" -eq 1
check "unexpected download: explains" contains "not the brightness-slider profile"
check "unexpected download: no file left behind" clean_dir

new_case backup
mkdir -p "$dest_dir"
printf 'old\n' >"$dest"
run_script install.sh
backups=("$dest".bak-*)
check "existing file: installs" cmp -s "$profile" "$dest"
check "existing file: keeps one backup" test "${#backups[@]}" -eq 1
check "existing file: backup holds the old file" grep -qx old "${backups[0]}"
check "existing file: reports the backup" contains "Saved your previous file"

new_case scripts-is-a-file
mkdir -p "$home/.config/gamescope"
touch "$dest_dir"
run_script install.sh
check "scripts path is a file: stops" test "$status" -eq 1
check "scripts path is a file: explains" contains "could not create"

new_case scripts-not-writable
mkdir -p "$dest_dir"
chmod 0555 "$dest_dir"
run_script install.sh
check "scripts folder not writable: stops" test "$status" -eq 1
check "scripts folder not writable: explains" contains "Not installed: could not write to the folder"
check "scripts folder not writable: changes nothing" clean_dir
chmod 0755 "$dest_dir"

new_case destination-is-a-folder
mkdir -p "$dest/inner"
run_script install.sh
check "destination is a folder: stops" test "$status" -eq 1
check "destination is a folder: explains" contains "Not installed: $dest is a folder"
check "destination is a folder: leaves it alone" test "$(ls -A "$dest")" == "inner"
check "destination is a folder: no file left behind" test "$(ls -A "$dest_dir")" == "lenovo.legiongo2.oled.lua"

new_case backup-fails
mkdir -p "$dest_dir"
printf 'old\n' >"$dest"
chmod 0000 "$dest"
run_script install.sh
chmod 0644 "$dest"
check "backup fails: stops" test "$status" -eq 1
check "backup fails: explains" contains "Not installed: could not save a copy of"
check "backup fails: keeps the old file" grep -qx old "$dest"
check "backup fails: no file left behind" test "$(ls -A "$dest_dir")" == "lenovo.legiongo2.oled.lua"

# --- uninstall.sh ---
new_case uninstall
run_script install.sh
run_script uninstall.sh
check "uninstall: succeeds" test "$status" -eq 0
check "uninstall: removes the profile" absent
check "uninstall: says to return to Game Mode" contains "Return to Gaming Mode"

new_case uninstall-nothing
run_script uninstall.sh
check "uninstall with nothing installed: exits cleanly" test "$status" -eq 0
check "uninstall with nothing installed: says so" contains "not installed"

new_case uninstall-unmarked
mkdir -p "$dest_dir"
printf 'someone else\n' >"$dest"
run_script uninstall.sh
check "uninstall of another file: stops" test "$status" -eq 1
check "uninstall of another file: keeps it" test -e "$dest"
check "uninstall of another file: explains" contains "was not installed by this fix"

new_case uninstall-folder
mkdir -p "$dest"
run_script uninstall.sh
check "uninstall of a folder: stops" test "$status" -eq 1
check "uninstall of a folder: keeps it" test -d "$dest"
check "uninstall of a folder: explains" contains "Not removed: $dest is a folder"
check "uninstall of a folder: no raw error" test "$(grep -c '^head:' <<<"$out")" -eq 0

new_case uninstall-not-writable
run_script install.sh
chmod 0555 "$dest_dir"
run_script uninstall.sh
chmod 0755 "$dest_dir"
check "uninstall from a read-only folder: stops" test "$status" -eq 1
check "uninstall from a read-only folder: keeps the profile" test -e "$dest"
check "uninstall from a read-only folder: explains" contains "Not removed: could not delete"

new_case uninstall-root
run_script install.sh
uid=0
run_script uninstall.sh
check "uninstall as root: stops" test "$status" -eq 1
check "uninstall as root: keeps the profile" test -e "$dest"

new_case uninstall-keeps-backups
mkdir -p "$dest_dir"
printf 'old\n' >"$dest"
run_script install.sh
run_script uninstall.sh
backups=("$dest".bak-*)
check "uninstall: keeps backups" test -e "${backups[0]}"

# --- truncated downloads ---
# curl | bash runs whatever arrives. A download cut off at any line must not
# change anything; only the complete script may act.
run_truncated() {
    out="$(head -n "$2" "$fix/$1" | env HOME="$home" PATH="$tests/stubs:$PATH" STUB_GAMESCOPE="$gamescope" \
        STUB_UID="$uid" LG2_OS_RELEASE="$case_dir/os-release" LG2_DRM_DIR="$case_dir/drm" \
        LG2_PROFILE_URL="$profile_url" bash 2>&1)"
}

truncated_install_changes_nothing() {
    local lines n
    lines="$(wc -l <"$fix/install.sh")"
    for ((n = 1; n < lines; n++)); do
        new_case "truncated-install-$n"
        run_truncated install.sh "$n"
        if [[ -e "$home/.config" ]]; then
            printf '     install.sh cut after line %d changed %s\n' "$n" "$home/.config"
            return 1
        fi
    done
}
check "truncated install.sh: changes nothing" truncated_install_changes_nothing

truncated_uninstall_changes_nothing() {
    local lines n
    lines="$(wc -l <"$fix/uninstall.sh")"
    for ((n = 1; n < lines; n++)); do
        new_case "truncated-uninstall-$n"
        run_script install.sh
        run_truncated uninstall.sh "$n"
        if [[ ! -e "$dest" ]]; then
            printf '     uninstall.sh cut after line %d removed the profile\n' "$n"
            return 1
        fi
    done
}
check "truncated uninstall.sh: changes nothing" truncated_uninstall_changes_nothing

complete_download_installs() {
    new_case piped-install
    run_truncated install.sh "$(wc -l <"$fix/install.sh")"
    cmp -s "$profile" "$dest"
}
check "complete install.sh through a pipe: installs" complete_download_installs

# --- tag ---
tag_of() { sed -n 's/^TAG="\(.*\)"$/\1/p' "$fix/$1"; }
tag="$(tag_of install.sh)"
check "tag: uninstall.sh matches install.sh" test "$(tag_of uninstall.sh)" == "$tag"
check "tag: README names only the scripts' tag" \
    test "$(grep -o 'brightness-slider-v[0-9][0-9.]*[0-9]' "$fix/README.md" | sort -u)" == "$tag"
check "tag: README links install, uninstall, and the manual download" \
    test "$(grep -c "$tag" "$fix/README.md")" -ge 3

# --- summary ---
if ((failures)); then
    printf '\n%d failed\n' "$failures"
    exit 1
fi
printf '\nall passed\n'
