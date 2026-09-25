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

# --- summary ---
if ((failures)); then
    printf '\n%d failed\n' "$failures"
    exit 1
fi
printf '\nall passed\n'
